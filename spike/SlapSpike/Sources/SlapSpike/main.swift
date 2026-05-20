// SlapSpike v2 — corrected IOKit probe for the Apple Silicon accelerometer.
//
// v1 failed because it used IOHIDManager (which requires a signed binary)
// and the wrong callback (input VALUE, not input REPORT). v2 fixes both.
//
// Technique credit: the AppleSPUHIDDevice + IOServiceMatching approach is
// public knowledge in these open-source projects:
//   - https://github.com/olvvier/apple-silicon-accelerometer
//   - https://github.com/AbdullahFID/MacSlapApp
//   - https://github.com/taigrr/spank
// This file is an independent reimplementation, not a copy of the above. 
//
// Pipeline:
//   1. IOServiceMatching("AppleSPUHIDDevice")
//   2. Iterate matching services
//   3. Filter by registry properties PrimaryUsagePage=0xFF00, PrimaryUsage=3
//   4. IOHIDDeviceCreate from the io_service_t
//   5. IOHIDDeviceOpen
//   6. Wake the sensor (ReportInterval / ReportingState / PowerState)
//   7. IOHIDDeviceRegisterInputReportCallback
//   8. Schedule on run loop
//   9. Parse 22-byte BMI286 reports: int32 LE at offsets 6/10/14, /65536 = g
//
// Run:
//   cd spike/SlapSpike
//   swift run SlapSpike
//
// Permissions: Terminal needs Input Monitoring. No sudo required.

import Foundation
import IOKit
import IOKit.hid

// MARK: - Configuration

let SAMPLE_DURATION_SECONDS: TimeInterval = 20
let SLAP_THRESHOLD_G: Double = 1.08        // calibrated: palm-rest slaps peak ~1.10-1.12g
let MOVEMENT_THRESHOLD_G: Double = 1.02    // print anything above gravity+2%
let ACCEL_SCALE_Q16: Double = 65536.0      // Bosch BMI286 fixed-point divisor

// Accelerometer device identifiers in the SPU's HID registry
let ACCEL_USAGE_PAGE: Int = 0xFF00         // Apple vendor page
let ACCEL_USAGE: Int = 3                   // accelerometer (9 = gyroscope)

// MARK: - Sample state, accessed from the report callback

final class SampleState {
    var reportsReceived: Int = 0
    var maxMagnitude: Double = 0
    var maxMagnitudeAt: TimeInterval = 0
    var slapSamples: [(t: TimeInterval, mag: Double, x: Double, y: Double, z: Double)] = []
    let startedAt = Date()

    func record(_ x: Double, _ y: Double, _ z: Double) {
        reportsReceived += 1
        let mag = sqrt(x*x + y*y + z*z)
        let t = Date().timeIntervalSince(startedAt)

        if mag > maxMagnitude {
            maxMagnitude = mag
            maxMagnitudeAt = t
        }

        if mag > SLAP_THRESHOLD_G {
            slapSamples.append((t, mag, x, y, z))
        }

        // Output strategy: stay silent unless something happens.
        //  - Once per second: one-line "idle" heartbeat (~840 samples in)
        //  - Above MOVEMENT_THRESHOLD_G but below SLAP_THRESHOLD_G: small bump line
        //  - Above SLAP_THRESHOLD_G: loud SLAP marker

        // Always print when we hit a new all-time peak — guarantees we see SOMETHING per slap
        // even if magnitude falls below SLAP_THRESHOLD_G.
        let isNewPeak = mag == maxMagnitude && mag > 1.02

        if mag >= SLAP_THRESHOLD_G {
            print(String(format: "  ⚡⚡⚡  SLAP  t=%5.2fs  mag=%.2fg   (x=%+.2f y=%+.2f z=%+.2f)",
                         t, mag, x, y, z))
        } else if isNewPeak {
            print(String(format: "   ★  peak  t=%5.2fs  mag=%.3fg   (x=%+.2f y=%+.2f z=%+.2f)  ← new max",
                         t, mag, x, y, z))
        } else if mag >= MOVEMENT_THRESHOLD_G {
            print(String(format: "   ·  bump  t=%5.2fs  mag=%.3fg",
                         t, mag))
        } else if reportsReceived % 840 == 0 {
            print(String(format: "       idle  t=%5.2fs  mag=%.3fg",
                         t, mag))
        }
    }
}

// MARK: - HID report parser

func readInt32LE(_ ptr: UnsafePointer<UInt8>, length: Int, offset: Int) -> Int32? {
    guard offset + 3 < length else { return nil }
    let b0 = UInt32(ptr[offset])
    let b1 = UInt32(ptr[offset + 1]) << 8
    let b2 = UInt32(ptr[offset + 2]) << 16
    let b3 = UInt32(ptr[offset + 3]) << 24
    return Int32(bitPattern: b0 | b1 | b2 | b3)
}

// MARK: - Phase 1: find the accelerometer service

print("== SlapSpike v2 — AppleSPUHIDDevice path ==\n")
print("Phase 1: searching for AppleSPUHIDDevice services...")

let matching = IOServiceMatching("AppleSPUHIDDevice")
guard matching != nil else {
    print("FAIL: could not build matching dictionary"); exit(1)
}

var iterator: io_iterator_t = 0
let matchResult = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
guard matchResult == KERN_SUCCESS else {
    print("FAIL: IOServiceGetMatchingServices returned \(matchResult)"); exit(1)
}
defer { IOObjectRelease(iterator) }

var accelService: io_service_t = 0
var scannedCount = 0

var service = IOIteratorNext(iterator)
while service != 0 {
    scannedCount += 1
    var props: Unmanaged<CFMutableDictionary>?
    IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0)
    if let dict = props?.takeRetainedValue() as? [String: Any] {
        let page = dict["PrimaryUsagePage"] as? Int ?? 0
        let usage = dict["PrimaryUsage"] as? Int ?? 0
        let kind = (page == ACCEL_USAGE_PAGE && usage == ACCEL_USAGE) ? "ACCEL" :
                   (page == ACCEL_USAGE_PAGE && usage == 9)            ? "gyro"  :
                                                                          "other"
        print(String(format: "  found SPU dev #%d: page=0x%04X usage=0x%02X  [\(kind)]",
                     scannedCount, page, usage))
        if page == ACCEL_USAGE_PAGE && usage == ACCEL_USAGE {
            accelService = service
            // don't release; we keep this one
        } else {
            IOObjectRelease(service)
        }
    } else {
        IOObjectRelease(service)
    }
    service = IOIteratorNext(iterator)
}

print("Phase 1 done: scanned \(scannedCount) SPU device(s).\n")

guard accelService != 0 else {
    print("FAIL: no SPU device matched accelerometer signature (0xFF00, usage 3).")
    print("      Your Mac may not expose the accelerometer this way.")
    exit(2)
}
defer { IOObjectRelease(accelService) }

// MARK: - Phase 2: create HID device, open, wake, register callback

print("Phase 2: opening accelerometer device...")

guard let device = IOHIDDeviceCreate(kCFAllocatorDefault, accelService) else {
    print("FAIL: IOHIDDeviceCreate returned nil"); exit(3)
}

let openResult = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
guard openResult == kIOReturnSuccess else {
    let hex = String(format: "0x%X", UInt32(bitPattern: openResult))
    print("FAIL: IOHIDDeviceOpen returned \(openResult) (\(hex))")
    if openResult == kIOReturnNotPermitted {
        print("      Grant Terminal Input Monitoring in System Settings.")
    }
    exit(4)
}
print("  device opened.")

// Wake the sensor. Without these, the device opens but emits no reports.
IOHIDDeviceSetProperty(device, "ReportInterval" as CFString, 1000 as CFNumber)
IOHIDDeviceSetProperty(device, "SensorPropertyReportingState" as CFString, 1 as CFNumber)
IOHIDDeviceSetProperty(device, "SensorPropertyPowerState" as CFString, 1 as CFNumber)
print("  sensor woken (ReportInterval=1000us, Reporting=on, Power=on).")

// Allocate a buffer for incoming reports. BMI286 reports are 22 bytes; 256 is generous.
let reportBufferSize = 256
let reportBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: reportBufferSize)
defer { reportBuffer.deallocate() }

let state = SampleState()
let stateOpaque = Unmanaged.passUnretained(state).toOpaque()

IOHIDDeviceRegisterInputReportCallback(
    device,
    reportBuffer,
    reportBufferSize,
    { context, _, _, _, _, report, reportLength in
        guard let context = context else { return }
        let state = Unmanaged<SampleState>.fromOpaque(context).takeUnretainedValue()

        // BMI286 22-byte format: int32 Q16 XYZ at offsets 6/10/14
        if reportLength >= 18,
           let rx = readInt32LE(report, length: reportLength, offset: 6),
           let ry = readInt32LE(report, length: reportLength, offset: 10),
           let rz = readInt32LE(report, length: reportLength, offset: 14)
        {
            let gx = Double(rx) / ACCEL_SCALE_Q16
            let gy = Double(ry) / ACCEL_SCALE_Q16
            let gz = Double(rz) / ACCEL_SCALE_Q16
            let mag = sqrt(gx*gx + gy*gy + gz*gz)

            // Sanity: real accel magnitudes sit between ~0.5g (free-fall not a thing here)
            // and ~10g for hard slaps. Reject parses that yield garbage.
            if mag > 0.3 && mag < 50.0 {
                state.record(gx, gy, gz)
            } else if state.reportsReceived < 5 {
                // Help debugging by dumping the first few raw reports so we can see
                // what format the device is actually using if Q16 is wrong.
                let bytes = (0..<min(reportLength, 22)).map { String(format: "%02X", report[$0]) }.joined(separator: " ")
                print("  raw report \(reportLength)B: \(bytes)")
            }
        }
    },
    stateOpaque
)

IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

print("\nPhase 3: listening for \(Int(SAMPLE_DURATION_SECONDS))s.\n")
print("  → Slap your MacBook (firmly, on the palm rest, a few times!)")
print("  → Watch for ⚡ markers when magnitude exceeds \(SLAP_THRESHOLD_G)g.\n")

// MARK: - Phase 3: stop after duration

DispatchQueue.main.asyncAfter(deadline: .now() + SAMPLE_DURATION_SECONDS) {
    print("\n== Done ==")
    print("Reports received:   \(state.reportsReceived)")
    print(String(format: "Max magnitude:      %.3fg (at t=%.2fs)", state.maxMagnitude, state.maxMagnitudeAt))
    print("Slap-like events:   \(state.slapSamples.count)  (threshold \(SLAP_THRESHOLD_G)g)")

    if state.reportsReceived == 0 {
        print("\n⚠️  Zero reports. Possibilities:")
        print("   - Input Monitoring permission not granted to your Terminal app")
        print("   - macOS version-specific change to the SPU interface")
        print("   - Device opened but ReportingState property didn't take effect")
    } else if state.maxMagnitude < 0.5 {
        print("\n⚠️  Reports flowing but magnitudes look static. Check parse offsets.")
    } else if state.slapSamples.isEmpty {
        print("\n△  Sensor is alive, but no slap exceeded \(SLAP_THRESHOLD_G)g.")
        print("   Try harder, or lower SLAP_THRESHOLD_G in this file.")
    } else {
        print("\n✓  SUCCESS. Sensor works. Slap detection is feasible.")
        print("   Use the max-magnitude value to set the threshold in SlapClassifier.swift.")
    }

    IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
    CFRunLoopStop(CFRunLoopGetMain())
    exit(0)
}

CFRunLoopRun()
