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

    /// How long after the first slap to keep counting follow-up slaps before firing.
    /// Lower = faster trigger but harder to land 2/3 slaps; higher = more leeway but longer delay.
    @Published var slapWindowSeconds: Double {
        didSet { UserDefaults.standard.set(slapWindowSeconds, forKey: Keys.window) }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)
            LaunchAtLogin.setEnabled(launchAtLogin)
        }
    }

    private enum Keys {
        static let threshold = "slap.threshold.g"
        static let window = "slap.window.seconds"
        static let launchAtLogin = "launch.at.login"
    }

    private init() {
        let storedThreshold = UserDefaults.standard.double(forKey: Keys.threshold)
        self.slapThresholdG = storedThreshold > 0 ? storedThreshold : 1.06
        let storedWindow = UserDefaults.standard.double(forKey: Keys.window)
        self.slapWindowSeconds = storedWindow > 0 ? storedWindow : 0.40
        self.launchAtLogin = UserDefaults.standard.bool(forKey: Keys.launchAtLogin)
    }
}
