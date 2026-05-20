// LaunchAtLogin — wrapper around SMAppService.
//
// Only meaningful in a code-signed .app bundle. When running via `swift run`, registration
// fails silently (the binary isn't a registered LaunchAgent). That's fine for development —
// the real DMG build (Weekend 4) will be a proper bundled app where this works.

import Foundation
import ServiceManagement

enum LaunchAtLogin {

    static func setEnabled(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else { return }
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status != .enabled {
                    try service.register()
                    print("SlapShift: launch-at-login enabled")
                }
            } else {
                if service.status == .enabled {
                    try service.unregister()
                    print("SlapShift: launch-at-login disabled")
                }
            }
        } catch {
            print("SlapShift: launch-at-login toggle failed: \(error.localizedDescription)")
            print("  → expected during `swift run` development; works in the bundled app")
        }
    }
}
