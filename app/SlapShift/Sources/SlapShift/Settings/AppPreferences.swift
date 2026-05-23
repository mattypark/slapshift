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

    // Key suffix bumped to v2 on 2026-05-22 so existing users pick up the
    // new forgiving defaults on next launch. The old keys tuned against a
    // pre-hysteresis classifier weren't transferable anyway.
    private enum Keys {
        static let threshold = "slap.threshold.g.v2"
        static let window = "slap.window.seconds.v2"
        static let launchAtLogin = "launch.at.login"
    }

    /// Defaults match SlapClassifier's hardcoded defaults so onboarding and
    /// settings always agree out of the box. Tune both in lockstep.
    static let defaultThresholdG: Double = 1.025
    static let defaultWindowSeconds: Double = 0.85

    private init() {
        let storedThreshold = UserDefaults.standard.double(forKey: Keys.threshold)
        self.slapThresholdG = storedThreshold > 0 ? storedThreshold : Self.defaultThresholdG
        let storedWindow = UserDefaults.standard.double(forKey: Keys.window)
        self.slapWindowSeconds = storedWindow > 0 ? storedWindow : Self.defaultWindowSeconds
        self.launchAtLogin = UserDefaults.standard.bool(forKey: Keys.launchAtLogin)
    }
}
