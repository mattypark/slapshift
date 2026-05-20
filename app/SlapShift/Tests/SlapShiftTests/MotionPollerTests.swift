// Tests for MotionPoller's byte-level parser.
//
// We can't unit-test the IOKit polling itself (no fake hardware in CI), but the
// Q16 little-endian parser is pure and runs on every sensor sample — worth a test.

import XCTest
@testable import SlapShift

final class MotionPollerTests: XCTestCase {

    /// Pack an Int32 little-endian into a byte array at the given offset.
    private func packLE(_ value: Int32, into bytes: inout [UInt8], at offset: Int) {
        let u = UInt32(bitPattern: value)
        bytes[offset]     = UInt8(u        & 0xFF)
        bytes[offset + 1] = UInt8((u >> 8)  & 0xFF)
        bytes[offset + 2] = UInt8((u >> 16) & 0xFF)
        bytes[offset + 3] = UInt8((u >> 24) & 0xFF)
    }

    func test_readInt32LE_parsesPositiveValue() {
        var bytes = [UInt8](repeating: 0, count: 22)
        packLE(65536, into: &bytes, at: 6)  // 1.0g in Q16

        let parsed = bytes.withUnsafeBufferPointer { buf in
            MotionPoller.readInt32LE(buf.baseAddress!, length: buf.count, offset: 6)
        }
        XCTAssertEqual(parsed, 65536)
    }

    func test_readInt32LE_parsesNegativeValue() {
        var bytes = [UInt8](repeating: 0, count: 22)
        packLE(-65536, into: &bytes, at: 10)  // -1.0g

        let parsed = bytes.withUnsafeBufferPointer { buf in
            MotionPoller.readInt32LE(buf.baseAddress!, length: buf.count, offset: 10)
        }
        XCTAssertEqual(parsed, -65536)
    }

    func test_readInt32LE_returnsNilWhenOffsetOutOfBounds() {
        let bytes: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0]  // length 8
        let parsed = bytes.withUnsafeBufferPointer { buf in
            MotionPoller.readInt32LE(buf.baseAddress!, length: buf.count, offset: 6)
        }
        // Need offset+3 < length, i.e. 6+3=9 > 8 → nil.
        XCTAssertNil(parsed)
    }

    func test_readInt32LE_packQ16ScaleRoundTrip() {
        // Synthesize a realistic palm-slap sample: ~1.10g packed at offsets 6/10/14
        // (the offsets MotionPoller's handleReport actually reads).
        var bytes = [UInt8](repeating: 0, count: 22)
        let q16 = Int32(1.10 * 65536)        // 72089
        packLE(q16, into: &bytes, at: 6)
        packLE(0,   into: &bytes, at: 10)
        packLE(0,   into: &bytes, at: 14)

        let rx = bytes.withUnsafeBufferPointer { MotionPoller.readInt32LE($0.baseAddress!, length: $0.count, offset: 6) }
        let scaled = Double(rx!) / 65536.0
        XCTAssertEqual(scaled, 1.10, accuracy: 0.0001)
    }
}
