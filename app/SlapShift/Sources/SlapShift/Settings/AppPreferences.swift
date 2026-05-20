// AppPreferences — global tunables that aren't per-mode.
//
// Persisted to UserDefaults (small key/value preferences, not user data — that's modes.json).
// Observable so the settings UI binds directly.

import Combine
import Foundation

final class AppPreferences: ObservableObject {

    static let shared = AppPreferences()

    @Published var slapThresholdG: Double {
        didSet { UserDefaults.standard.set(slapThresholdG, forKey: Keys.threshold) }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)
            LaunchAtLogin.setEnabled(launchAtLogin)
        }
    }

    private enum Keys {
        static let threshold = "slap.threshold.g"
        static let launchAtLogin = "launch.at.login"
    }

    private init() {
        let storedThreshold = UserDefaults.standard.double(forKey: Keys.threshold)
        self.slapThresholdG = storedThreshold > 0 ? storedThreshold : 1.06
        self.launchAtLogin = UserDefaults.standard.bool(forKey: Keys.launchAtLogin)
    }
}
