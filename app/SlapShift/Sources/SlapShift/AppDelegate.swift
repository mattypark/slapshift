// AppDelegate — the seam between motion events and mode execution.
//
// Owns: menu bar controller, mode store, motion stack, executor, settings window, prefs.
// Does: wire the slap callback to (look up mode by count) → (execute) → (flash icon).
//       Bind the sensitivity slider to the live SlapClassifier threshold.

import AppKit
import Combine
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let modeStore = ModeStore()
    private let executor = ActionExecutor()
    private let prefs = AppPreferences.shared
    private let licenseManager = LicenseManager()
    private var menuBar: MenuBarController!
    private var motion: MotionPoller!
    private var classifier: SlapClassifier!
    private var settingsWindow: SettingsWindow!
    private var onboardingWindow: OnboardingWindow?
    private var onboardingState: OnboardingState?
    private var licenseSheet: LicenseSheet?
    private var permissionPollTimer: Timer?
    private var motionRunning: Bool = false
    private var menuBarInstalled: Bool = false
    private var cancellables: Set<AnyCancellable> = []

    /// UserDefaults flag — flipped once the user finishes the onboarding flow.
    /// Until then, every launch re-presents onboarding so they don't get stranded.
    private static let onboardingCompleteKey = "onboarding.complete"
    private var onboardingComplete: Bool {
        get { UserDefaults.standard.bool(forKey: Self.onboardingCompleteKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.onboardingCompleteKey) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("== SlapShift launched ==")
        modeStore.loadOrSeedDefaults()
        print("Modes loaded: \(modeStore.modes.map { "\($0.slapCount)→\($0.name)" }.joined(separator: ", "))")

        settingsWindow = SettingsWindow(modeStore: modeStore, prefs: prefs)

        // First-launch convenience: pop the settings window automatically so the user can
        // customize before the menu bar icon hunt begins. Triggered by SLAPSHIFT_FIRST_RUN env var
        // OR if the modes are still the seeded defaults (heuristic: no edits made yet).
        if ProcessInfo.processInfo.environment["SLAPSHIFT_OPEN_SETTINGS"] != nil {
            DispatchQueue.main.async { [weak self] in self?.settingsWindow.show() }
        }

        menuBar = MenuBarController(modeStore: modeStore)
        menuBar.onQuit = { NSApp.terminate(nil) }
        menuBar.onOpenSettings = { [weak self] in self?.settingsWindow.show() }
        menuBar.onTestSlap = { [weak self] count in
            print("Test: simulating \(count) slap(s)")
            self?.handleSlap(SlapEvent(count: count, peakG: 1.20, timestamp: 0))
        }

        // Rebuild the menu when modes change so "1 slap → Coding" labels stay accurate.
        modeStore.$modes
            .sink { [weak self] _ in
                guard let self = self, self.menuBarInstalled else { return }
                self.menuBar.rebuildMenu()
            }
            .store(in: &cancellables)

        // Menu bar icon stays hidden until the user finishes onboarding AND has
        // an active license. Until then there are no controls (Settings, Test,
        // Quit) reachable from the menu bar — the user is gated through the
        // onboarding window first. installMenuBarIfReady() is the one place
        // that flips the icon on.
        installMenuBarIfReady()
        licenseManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.installMenuBarIfReady() }
            .store(in: &cancellables)

        classifier = SlapClassifier()
        classifier.slapThresholdG = prefs.slapThresholdG
        classifier.windowSeconds = prefs.slapWindowSeconds
        classifier.onSlap = { [weak self] event in
            self?.handleSlap(event)
        }

        // Live-bind the sensitivity slider to the classifier threshold.
        prefs.$slapThresholdG
            .sink { [weak self] newValue in
                self?.classifier.slapThresholdG = newValue
            }
            .store(in: &cancellables)

        // Live-bind the slap window slider so multi-slap timing updates without restart.
        prefs.$slapWindowSeconds
            .sink { [weak self] newValue in
                self?.classifier.windowSeconds = newValue
            }
            .store(in: &cancellables)

        motion = MotionPoller()
        motion.onSample = { [weak self] sample in
            self?.classifier.ingest(sample)
        }

        do {
            try motion.start()
            motionRunning = true
            if menuBarInstalled {
                menuBar.setState(.armed)
            }
            print("Motion poller started — slap your MacBook to fire a mode")
            print("Open Settings from the menu bar icon to customize modes")
        } catch {
            print("ERROR: motion start failed: \(error.localizedDescription)")
            print("  → likely Input Monitoring permission needed. Check System Settings.")
            if menuBarInstalled {
                menuBar.setState(.error(error.localizedDescription))
            }
        }

        // Onboarding gate — runs AFTER the full app stack is wired so the test-slap
        // step can hook into the live classifier callbacks via `onboardingState`.
        if !onboardingComplete {
            presentOnboarding()
        }

        // License bootstrap. Loads the Keychain cache and (if grace expired)
        // talks to the server in the background. Doesn't block startup —
        // the paywall fires on the first real slap if the user is unlicensed.
        Task { @MainActor in
            await licenseManager.bootstrap()
        }
    }

    // MARK: - URL scheme (slapshift://license?key=...)

    /// Handles deep links from the /success page's "Activate SlapShift →" button.
    /// One-click flow: the buyer's browser opens slapshift://license?key=XXX, macOS
    /// routes it here, and we hand the key straight to LicenseManager.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard url.scheme == "slapshift" else { continue }
            handleSlapshiftURL(url)
        }
    }

    private func handleSlapshiftURL(_ url: URL) {
        // Expected shape: slapshift://license?key=SLAP-...
        guard url.host == "license" || url.path.hasPrefix("/license") else {
            print("Ignoring unrecognized slapshift:// URL: \(url)")
            return
        }
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let key = comps?.queryItems?.first(where: { $0.name == "key" })?.value,
              !key.isEmpty else {
            print("slapshift://license missing ?key= param")
            // Still show the sheet so the user can paste manually.
            presentLicenseSheet(prefilling: nil)
            return
        }
        presentLicenseSheet(prefilling: key)
    }

    // MARK: - Onboarding

    /// Build the OnboardingState, wire its callbacks to real subsystems, and show the window.
    /// The slap pipeline routes the next slap to `onboardingState.testSlapDetected` instead of
    /// firing a mode, so the user can confirm the sensor works without their workspace transforming.
    private func presentOnboarding() {
        let state = OnboardingState(authService: StubAuthService())

        // Permission step — open the pane, then poll motion.start() until it succeeds.
        state.openInputMonitoringSettings = { [weak self] in
            self?.openInputMonitoringPane()
            self?.startPermissionPolling()
        }
        // Reflect current permission state immediately — motion may already be running.
        state.permissionGranted = motionRunning

        // Shortcuts step — run the installer; mark installed when bundled files are
        // handed off to Shortcuts.app. Zero bundled files is also "done" (no-op case).
        state.installDefaultShortcuts = { [weak state] in
            let count = ShortcutInstaller.installBundledShortcuts()
            print("Onboarding: opened \(count) bundled shortcut file(s) for install confirmation")
            state?.shortcutsInstalled = true
        }

        // Paywall step — "Buy now" routes to Stripe Checkout in the user's browser.
        // We don't open an in-app webview; Stripe's hosted checkout is the trusted
        // payment surface and the redirect back to slapshift://license activates
        // the key automatically once the webhook completes.
        state.openCheckout = { [weak state] in
            let email = state?.email.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            var comps = URLComponents(string: "https://slapshift.app/api/checkout")!
            if !email.isEmpty {
                comps.queryItems = [URLQueryItem(name: "email", value: email)]
            }
            if let url = comps.url {
                NSWorkspace.shared.open(url)
            }
        }

        // Paywall "I already have a license" — open the existing manual-entry sheet.
        state.openLicenseSheet = { [weak self] in
            self?.presentLicenseSheet(prefilling: nil)
        }

        onboardingState = state
        onboardingWindow = OnboardingWindow(state: state, onFinish: { [weak self] in
            self?.onboardingComplete = true
            self?.persistOnboardingProfile(state)
            self?.onboardingState = nil
            self?.onboardingWindow = nil
            self?.stopPermissionPolling()
            // Once onboarding is done, re-evaluate whether the menu bar icon
            // should appear. It only appears once they ALSO have a license.
            self?.installMenuBarIfReady()
            print("Onboarding complete")
        })
        onboardingWindow?.show()
    }

    /// Install the menu bar icon if and only if onboarding has been completed
    /// AND the user has an active license. Until both conditions are true the
    /// app has no visible surface other than the onboarding window — slaps are
    /// silently ignored, the icon is absent, and there's no Settings/Test menu.
    /// Safe to call repeatedly; the first satisfying call wins and later calls
    /// are no-ops.
    private func installMenuBarIfReady() {
        guard !menuBarInstalled,
              onboardingComplete,
              licenseManager.state.isLicensed else { return }
        menuBar.install()
        menuBarInstalled = true
        if motionRunning {
            menuBar.setState(.armed)
        }
        print("Menu bar icon installed (look for hand.tap symbol top-right)")
    }

    /// Save the lightweight onboarding profile (name, email, usage tags) to
    /// UserDefaults so it survives relaunch and Phase 2 can sync it to Supabase.
    private func persistOnboardingProfile(_ state: OnboardingState) {
        let defaults = UserDefaults.standard
        defaults.set(state.name, forKey: "onboarding.name")
        defaults.set(state.email, forKey: "onboarding.email")
        defaults.set(state.provider?.rawValue, forKey: "onboarding.provider")
        defaults.set(Array(state.usage), forKey: "onboarding.usage")
    }

    /// Open System Settings directly to the Input Monitoring pane (Privacy & Security).
    private func openInputMonitoringPane() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        NSWorkspace.shared.open(url)
    }

    /// Re-attempt motion.start() every 1.5s until it succeeds (user granted permission)
    /// or onboarding ends. Cheap to poll — start() is a quick IOKit handshake.
    private func startPermissionPolling() {
        stopPermissionPolling()
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self = self, let state = self.onboardingState, !state.permissionGranted else {
                self?.stopPermissionPolling()
                return
            }
            do {
                try self.motion.start()
                self.motionRunning = true
                if self.menuBarInstalled {
                    self.menuBar.setState(.armed)
                }
                state.permissionGranted = true
                self.stopPermissionPolling()
                print("Onboarding: motion permission confirmed")
            } catch {
                // Still waiting on the user — keep polling.
            }
        }
    }

    private func stopPermissionPolling() {
        permissionPollTimer?.invalidate()
        permissionPollTimer = nil
    }

    private func handleSlap(_ event: SlapEvent) {
        // If onboarding is active and on the test-slap step, swallow the slap to confirm
        // the sensor works — don't fire a real mode mid-tutorial. Flash the icon ONLY
        // if it's actually visible (i.e. user already finished onboarding once before,
        // which shouldn't happen here, but guard anyway).
        if let state = onboardingState, !state.testSlapDetected {
            state.testSlapDetected = true
            print("Onboarding: test slap detected (\(event.count) slap(s) @ \(String(format: "%.2f", event.peakG))g)")
            return
        }

        // Hard gate. The app does NOTHING — no flash, no popup, no mode — until
        // the user has both completed onboarding AND activated a license. The
        // paywall lives inside the onboarding flow itself, so an unlicensed
        // user who hasn't finished onboarding will simply see no response from
        // their slaps until they finish + buy. This matches the user's spec:
        // "it shouldn't work at all until... I finish the onboarding and
        // actually buy it."
        guard onboardingComplete, licenseManager.state.isLicensed else {
            return
        }

        menuBar.flash()

        guard let mode = modeStore.mode(forSlapCount: event.count) else {
            print("⚠️  \(event.count) slap(s) detected but no mode bound — ignoring")
            return
        }

        print(String(format: "⚡ %d slap%@ @ %.2fg → '%@' (open: %d, quit: %d, urls: %d)",
                     event.count,
                     event.count > 1 ? "s" : "",
                     event.peakG,
                     mode.name,
                     mode.appsToOpen.count,
                     mode.appsToQuit.count,
                     mode.urlsToOpen.count))
        executor.execute(mode)
    }

    // MARK: - License sheet

    /// Show the paywall / key-entry sheet. If `prefilling` is non-nil, the sheet
    /// auto-attempts activation on appear (used by the slapshift://license URL flow).
    private func presentLicenseSheet(prefilling key: String?) {
        // Reuse an existing window if it's already up.
        if let existing = licenseSheet {
            existing.show()
            return
        }
        let sheet = LicenseSheet(
            manager: licenseManager,
            initialKey: key,
            onClose: { [weak self] in self?.licenseSheet = nil }
        )
        licenseSheet = sheet
        sheet.show()
    }

    func applicationWillTerminate(_ notification: Notification) {
        motion?.stop()
    }
}
