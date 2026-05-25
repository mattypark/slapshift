// MotionPoller — production port of the SlapSpike v2 IOKit code.
//
// What changed from the spike:
//   - Errors propagate via `throws` instead of `exit()`
//   - Sample delivery via callback closure instead of inline printing
//   - `stop()` so we can tear down on app quit
//   - No phase-1 debug printing in the happy path
//
// Hardware specifics (verified by SlapSpike v2 on 2026-05-19):
//   - Service:           AppleSPUHIDDevice
//   - Vendor page:       0xFF00
//   - Accel usage:       3   (gyro is 9)
//   - Report length:     22 bytes
//   - Accel offsets:     int32 LE at 6, 10, 14
//   - Scale:             65536 (Q16 fixed point) → g
//   - Native sample rate: ~840 Hz

import Foundation
import IOKit
import IOKit.hid

struct MotionSample {
    let timestamp: TimeInterval   // monotonic seconds since poller start
    let x: Double                  // g
    let y: Double
    let z: Double
    let magnitude: Double          // sqrt(x²+y²+z²), g
}

enum MotionError: LocalizedError {
    case serviceMatchingFailed
    case noAccelerometerFound
    case deviceCreateFailed
    case deviceOpenFailed(IOReturn)

    var errorDescription: String? {
        switch self {
        case .serviceMatchingFailed:
            return "Could not build IOKit matching dictionary"
        case .noAccelerometerFound:
            return "No AppleSPUHIDDevice with accelerometer signature (0xFF00/0x03) found"
        case .deviceCreateFailed:
            return "IOHIDDeviceCreate returned nil"
        case .deviceOpenFailed(let code):
            if code == kIOReturnNotPermitted {
                return "Permission denied — grant Input Monitoring in System Settings"
            }
            return "IOHIDDeviceOpen failed (\(String(format: "0x%X", UInt32(bitPattern: code))))"
        }
    }
}

final class MotionPoller {

    /// Canonical macOS Input Monitoring permission status. Mirrors what the
    /// user sees in System Settings → Privacy & Security → Input Monitoring.
    ///
    /// We previously inferred permission from whether `IOHIDDeviceOpen`
    /// succeeded at app launch, but that is unreliable: on machines where a
    /// prior build of SlapShift had been authorized (or where macOS cached
    /// a grant against the bundle ID + signature), `IOHIDDeviceOpen` returns
    /// `kIOReturnSuccess` *before* the user has ever toggled the checkbox
    /// for the current install, so onboarding would show "Permission
    /// granted" instantly without the user doing anything. The right
    /// question is "does the OS say we have Listen access?", and the API
    /// for that question is `IOHIDCheckAccess(.listenEvent)`.
    enum PermissionStatus {
        case granted
        case denied
        case notDetermined
    }

    static func permissionStatus() -> PermissionStatus {
        // IOHIDAccessType is a typealias for UInt32, not a Swift enum, so
        // the switch needs a plain `default:` rather than `@unknown default:`.
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted:      return .granted
        case kIOHIDAccessTypeDenied:       return .denied
        default:                           return .notDetermined
        }
    }

    /// Provoke the OS permission prompt. Safe to call repeatedly — macOS
    /// only shows the dialog the first time per install, and never re-prompts
    /// after the user has answered. Returns true if access is granted right
    /// now (same as `permissionStatus() == .granted`).
    @discardableResult
    static func requestPermission() -> Bool {
        return IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    var onSample: ((MotionSample) -> Void)?

    private var device: IOHIDDevice?
    private var accelService: io_service_t = 0
    private var reportBuffer: UnsafeMutablePointer<UInt8>?
    private let reportBufferSize = 256
    private let startedAt = Date()

    private static let accelUsagePage = 0xFF00
    private static let accelUsage = 3
    private static let scaleQ16 = 65536.0

    func start() throws {
        let service = try findAccelerometerService()
        accelService = service

        guard let dev = IOHIDDeviceCreate(kCFAllocatorDefault, service) else {
            throw MotionError.deviceCreateFailed
        }

        let openResult = IOHIDDeviceOpen(dev, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openResult == kIOReturnSuccess else {
            throw MotionError.deviceOpenFailed(openResult)
        }

        // Wake the sensor. Without these properties the device opens but emits zero reports.
        IOHIDDeviceSetProperty(dev, "ReportInterval" as CFString, 1000 as CFNumber)
        IOHIDDeviceSetProperty(dev, "SensorPropertyReportingState" as CFString, 1 as CFNumber)
        IOHIDDeviceSetProperty(dev, "SensorPropertyPowerState" as CFString, 1 as CFNumber)

        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: reportBufferSize)
        reportBuffer = buffer
        device = dev

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(
            dev,
            buffer,
            reportBufferSize,
            MotionPoller.reportCallback,
            context
        )

        IOHIDDeviceScheduleWithRunLoop(dev, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    }

    func stop() {
        if let dev = device {
            IOHIDDeviceUnscheduleFromRunLoop(dev, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDDeviceClose(dev, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        device = nil
        reportBuffer?.deallocate()
        reportBuffer = nil
        if accelService != 0 {
            IOObjectRelease(accelService)
            accelService = 0
        }
    }

    deinit { stop() }

    // MARK: - Service discovery

    private func findAccelerometerService() throws -> io_service_t {
        guard let matching = IOServiceMatching("AppleSPUHIDDevice") else {
            throw MotionError.serviceMatchingFailed
        }

        var iterator: io_iterator_t = 0
        let matchResult = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard matchResult == KERN_SUCCESS else {
            throw MotionError.noAccelerometerFound
        }
        defer { IOObjectRelease(iterator) }

        var found: io_service_t = 0
        var service = IOIteratorNext(iterator)
        while service != 0 {
            var props: Unmanaged<CFMutableDictionary>?
            IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0)
            if let dict = props?.takeRetainedValue() as? [String: Any],
               let page = dict["PrimaryUsagePage"] as? Int,
               let usage = dict["PrimaryUsage"] as? Int,
               page == Self.accelUsagePage,
               usage == Self.accelUsage,
               found == 0
            {
                found = service
                // do NOT release; we hand it back to the caller
            } else {
                IOObjectRelease(service)
            }
            service = IOIteratorNext(iterator)
        }

        guard found != 0 else { throw MotionError.noAccelerometerFound }
        return found
    }

    // MARK: - Report parsing

    private static let reportCallback: IOHIDReportCallback = { context, _, _, _, _, report, reportLength in
        guard let context = context else { return }
        let poller = Unmanaged<MotionPoller>.fromOpaque(context).takeUnretainedValue()
        poller.handleReport(report, length: reportLength)
    }

    private func handleReport(_ report: UnsafePointer<UInt8>, length: Int) {
        guard length >= 18,
              let rx = Self.readInt32LE(report, length: length, offset: 6),
              let ry = Self.readInt32LE(report, length: length, offset: 10),
              let rz = Self.readInt32LE(report, length: length, offset: 14)
        else { return }

        let gx = Double(rx) / Self.scaleQ16
        let gy = Double(ry) / Self.scaleQ16
        let gz = Double(rz) / Self.scaleQ16
        let mag = (gx*gx + gy*gy + gz*gz).squareRoot()

        // Sanity: reject garbage parses. Real magnitudes are ~0.8g (light freefall) to ~10g (hard slap).
        guard mag > 0.3 && mag < 50.0 else { return }

        let sample = MotionSample(
            timestamp: Date().timeIntervalSince(startedAt),
            x: gx, y: gy, z: gz, magnitude: mag
        )
        onSample?(sample)
    }

    // Internal (not private) so SlapShiftTests can exercise it directly.
    static func readInt32LE(_ ptr: UnsafePointer<UInt8>, length: Int, offset: Int) -> Int32? {
        guard offset + 3 < length else { return nil }
        let b0 = UInt32(ptr[offset])
        let b1 = UInt32(ptr[offset + 1]) << 8
        let b2 = UInt32(ptr[offset + 2]) << 16
        let b3 = UInt32(ptr[offset + 3]) << 24
        return Int32(bitPattern: b0 | b1 | b2 | b3)
    }
}
