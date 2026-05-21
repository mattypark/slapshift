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
        menuBar.install()

        // Rebuild the menu when modes change so "1 slap → Coding" labels stay accurate.
        modeStore.$modes
            .sink { [weak self] _ in self?.menuBar.rebuildMenu() }
            .store(in: &cancellables)

        print("Menu bar icon installed (look for hand.tap symbol top-right)")

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
            menuBar.setState(.armed)
            print("Motion poller started — slap your MacBook to fire a mode")
            print("Open Settings from the menu bar icon to customize modes")
        } catch {
            print("ERROR: motion start failed: \(error.localizedDescription)")
            print("  → likely Input Monitoring permission needed. Check System Settings.")
            menuBar.setState(.error(error.localizedDescription))
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
        let state = OnboardingState()

        // Step 2 — Input Monitoring. Open the pane, then poll motion.start() until it succeeds.
        state.openInputMonitoringSettings = { [weak self] in
            self?.openInputMonitoringPane()
            self?.startPermissionPolling()
        }
        // Reflect current permission state immediately — motion may already be running.
        state.permissionGranted = motionRunning

        // Step 3 — Shortcuts. Run the installer; mark installed if anything shipped.
        // Zero bundled files is also "done" (it's the no-op case) — user can build shortcuts by hand.
        state.installDefaultShortcuts = { [weak state] in
            let count = ShortcutInstaller.installBundledShortcuts()
            print("Onboarding: opened \(count) bundled shortcut file(s) for install confirmation")
            state?.shortcutsInstalled = true
        }

        onboardingState = state
        onboardingWindow = OnboardingWindow(state: state, onFinish: { [weak self] in
            self?.onboardingComplete = true
            self?.onboardingState = nil
            self?.onboardingWindow = nil
            self?.stopPermissionPolling()
            print("Onboarding complete")
        })
        onboardingWindow?.show()
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
                self.menuBar.setState(.armed)
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
        menuBar.flash()

        // If onboarding is active and on the test-slap step, swallow the slap to confirm
        // the sensor works — don't fire a real mode mid-tutorial. Once the user finishes
        // onboarding, slaps resume normal mode execution.
        if let state = onboardingState, !state.testSlapDetected {
            state.testSlapDetected = true
            print("Onboarding: test slap detected (\(event.count) slap(s) @ \(String(format: "%.2f", event.peakG))g)")
            return
        }

        // Paywall gate. The first real slap from an unlicensed user opens the
        // purchase + key entry sheet instead of firing a mode. Same UX shape as
        // the onboarding intercept above — swallow the slap, present the prompt,
        // resume normal behavior once they buy/activate (or dismiss).
        if !licenseManager.state.isLicensed {
            print("Paywall: slap intercepted, license not active")
            presentLicenseSheet(prefilling: nil)
            return
        }

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
