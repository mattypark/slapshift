// AutoUpdater — wraps Sparkle's SPUStandardUpdaterController.
//
// Sparkle delivers in-app updates without going through the Mac App Store.
// Flow:
//   1. App launches. Sparkle reads SUFeedURL from Info.plist (the appcast.xml
//      hosted at slapshift.app/appcast.xml).
//   2. Once a day (SUScheduledCheckInterval=86400s) AND on every launch,
//      Sparkle fetches the appcast, compares each <item>'s sparkle:version
//      against CFBundleVersion of the running app.
//   3. If a newer version exists, Sparkle verifies the EdDSA signature on
//      the DMG against SUPublicEDKey in Info.plist, then shows a native
//      "Update available" sheet.
//   4. User clicks Install Update → Sparkle downloads + verifies + swaps
//      + relaunches. License key persists in Keychain so it survives.
//
// The "Check for Updates…" menu items in the menu bar AND the app's main
// menu route to `checkForUpdates()` so the user can poke it manually
// (debugging or impatience).

import Sparkle

final class AutoUpdater {

    /// Sparkle's batteries-included controller: owns the SPUUpdater, hooks
    /// the standard user-driver UI (sheets, alerts), and starts the
    /// background check on init.
    private let controller: SPUStandardUpdaterController

    init() {
        // startingUpdater:true kicks off the launch check + schedules the
        // daily background check. Delegates left nil — the default behavior
        // (read SUFeedURL/SUPublicEDKey from Info.plist, show standard
        // sheets) is exactly what we want.
        self.controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    /// Wired to the menu items. Same code path Sparkle hits automatically;
    /// the difference is the user-initiated path shows "you're up to date"
    /// when no update exists, instead of staying silent.
    @objc func checkForUpdates(_ sender: Any?) {
        controller.checkForUpdates(sender)
    }
}
