// MachineId — stable per-Mac identifier used for license binding.
//
// We pull the IOPlatformUUID from IORegistry — the same value Apple uses to
// identify the hardware. It survives macOS reinstalls and user account changes
// but is unique to the physical machine. This is exactly what we want for a
// "one license = one Mac" binding policy.
//
// If IORegistry is unavailable (extraordinarily unlikely on macOS), we fall
// back to a randomly-generated UUID persisted to Keychain so the user isn't
// blocked. Less ideal (a reinstall would unbind) but never zero.

import Foundation
import IOKit

enum MachineId {

    /// Lazily-resolved machine identifier. Cached for the process lifetime.
    static let current: String = resolve()

    private static func resolve() -> String {
        if let hw = ioPlatformUUID() {
            return hw
        }
        return fallbackUUID()
    }

    private static func ioPlatformUUID() -> String? {
        let entry = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard entry != 0 else { return nil }
        defer { IOObjectRelease(entry) }
        let cfKey = "IOPlatformUUID" as CFString
        guard let prop = IORegistryEntryCreateCFProperty(entry, cfKey, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String,
              !prop.isEmpty else {
            return nil
        }
        return prop
    }

    /// Persisted random UUID — only ever used if IORegistry refuses.
    private static func fallbackUUID() -> String {
        let key = "machine.id.fallback"
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: key)
        return fresh
    }
}
