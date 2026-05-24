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
    private let stats = SlapStats()
private let licenseManager = LicenseManager()
let motionMonitor = MotionMonitor()
    private var menuBar: MenuBarController!
    private var motion: MotionPoller!
    private var classifier: SlapClassifier!
    private var settingsWindow: SettingsWindow!
    private var homeWindow: HomeWindow?
    private var onboardingWindow: OnboardingWindow?
    private var onboardingState: OnboardingState?
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
        // Install a minimal main menu so standard text-editing shortcuts
        // (Cmd+C/V/X/A, Cmd+Z) route through the responder chain into
        // focused TextFields. Without this, Edit-menu actions are dead
        // because LSUIElement=true apps don't get one automatically.
        installMainMenu()
        modeStore.loadOrSeedDefaults()
        print("Modes loaded: \(modeStore.modes.map { "\($0.slapCount)→\($0.name)" }.joined(separator: ", "))")

        settingsWindow = SettingsWindow(modeStore: modeStore, prefs: prefs, motionMonitor: motionMonitor)

        // First-launch convenience: pop the settings window automatically so the user can
        // customize before the menu bar icon hunt begins. Triggered by SLAPSHIFT_FIRST_RUN env var
        // OR if the modes are still the seeded defaults (heuristic: no edits made yet).
        if ProcessInfo.processInfo.environment["SLAPSHIFT_OPEN_SETTINGS"] != nil {
            DispatchQueue.main.async { [weak self] in self?.settingsWindow.show() }
        }

        menuBar = MenuBarController(modeStore: modeStore)
        menuBar.onQuit = { NSApp.terminate(nil) }
        menuBar.onOpenSettings = { [weak self] in self?.settingsWindow.show() }
        menuBar.onOpenHome = { [weak self] in self?.showHome() }
        menuBar.onTestSlap = { [weak self] count in
            print("Test: simulating \(count) slap(s)")
            self?.handleSlap(SlapEvent(count: count, peakG: 1.20, timestamp: 0))
        }
        menuBar.onSignOut = { [weak self] in self?.confirmAndSignOut() }

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
            // Fan the slap out to both the meter (so the settings UI can flash
            // red on detection) AND the real mode-execution pipeline. The
            // meter never gates on license — even unlicensed users see the
            // sensor working during onboarding demo steps.
            self?.motionMonitor.recordSlap(event)
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
        // Fork the sample stream: the classifier consumes raw samples at full
        // rate for rising-edge detection; the motion monitor consumes the same
        // stream but smooths + decimates internally to drive the settings live
        // meter at ~30Hz. Both consumers are cheap; neither starves the other.
        motion.onSample = { [weak self] sample in
            self?.classifier.ingest(sample)
            self?.motionMonitor.ingest(sample)
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
            // Skip the license bootstrap entirely on first run. A fresh user
            // has no Keychain entry to read, so calling SecItemCopyMatching
            // here only risks the macOS ACL prompt firing before any UI has
            // appeared (e.g. after a re-signed build). The bootstrap will
            // fire from the onboarding `finish` closure after they've gone
            // through the flow and seen what the app is.
            presentOnboarding()
        } else {
            // Returning user — they've onboarded before, so reading the
            // Keychain license cache is expected and the prompt (if any
            // appears) makes sense in context. Once bootstrap completes, if
            // the cached license is still valid, surface the home window so
            // a Spotlight / Raycast / Finder launch produces something
            // visible. Without this the cold launch is silent (LSUIElement=
            // accessory means no Dock icon and no auto-window), and users
            // think the app didn't start. showHome() flips activation policy
            // to .regular so the Dock icon appears for the lifetime of the
            // window.
            Task { @MainActor in
                await licenseManager.bootstrap()
                if self.licenseManager.state.isLicensed {
                    self.showHome()
                } else {
                    // Cached license missing / expired / revoked — drop the
                    // user back into onboarding so they can re-paste their
                    // key on the paywall (machine-id binding re-activates
                    // instantly on the same Mac).
                    self.presentOnboarding()
                }
            }
        }
    }

    // MARK: - Re-launch (Finder / Spotlight / Dock click while running)

    /// Called when the user opens SlapShift again while it's already running.
    /// Without this handler, double-clicking the .app does nothing visible —
    /// macOS just brings the (windowless, LSUIElement) process to the front,
    /// the user sees no window, no Dock bounce, no menu bar change, and
    /// concludes the launch failed. They quit and retry, which only works
    /// because the second launch is a real cold start.
    ///
    /// Fix: surface a window every time. The right window depends on state.
    /// - Onboarding window already open → just focus it (don't rebuild state).
    /// - Onboarding not finished, or unlicensed → re-present onboarding so
    ///   the user lands on the next step they need to take.
    /// - Fully set up → show the Home dashboard, same as menu bar "Show Home".
    ///
    /// Returning false tells AppKit "I handled this, don't auto-create a
    /// window for me." Both window types call setActivationPolicy(.regular)
    /// inside show(), so the app briefly appears in the Dock too — giving the
    /// user the visual feedback they expect from a normal app launch.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if onboardingWindow != nil {
            onboardingWindow?.show()
            return false
        }
        if !onboardingComplete || !licenseManager.state.isLicensed {
            presentOnboarding()
            return false
        }
        showHome()
        return false
    }

    // MARK: - Main menu (enables Cmd+C/V/X/A in TextFields)

    /// Build a minimal NSMainMenu with App + Edit submenus. LSUIElement apps
    /// don't get one by default, which silently breaks every standard text
    /// shortcut (Cmd+C/V/X, Select All, Undo) the moment any TextField gains
    /// focus. Each item points at the standard responder action so the
    /// focused field handles it for free.
    private func installMainMenu() {
        let mainMenu = NSMenu()

        // App menu — required slot so the OS knows where the app name goes.
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About SlapShift",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide SlapShift",
                        action: #selector(NSApplication.hide(_:)),
                        keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: "Hide Others",
                                         action: #selector(NSApplication.hideOtherApplications(_:)),
                                         keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All",
                        action: #selector(NSApplication.unhideAllApplications(_:)),
                        keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit SlapShift",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        // Edit menu — the whole point of this method. Standard responder
        // selectors flow into the first responder (the focused NSTextView
        // inside a SwiftUI TextField), giving free Cut/Copy/Paste/Undo.
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo",
                         action: Selector(("undo:")),
                         keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo",
                                    action: Selector(("redo:")),
                                    keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut",
                         action: #selector(NSText.cut(_:)),
                         keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy",
                         action: #selector(NSText.copy(_:)),
                         keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste",
                         action: #selector(NSText.paste(_:)),
                         keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All",
                         action: #selector(NSText.selectAll(_:)),
                         keyEquivalent: "a")
        editMenuItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
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
        let key = comps?.queryItems?.first(where: { $0.name == "key" })?.value ?? ""

        // The deep link only matters during onboarding — the paywall step has
        // the inline license field that consumes the key. If onboarding isn't
        // open, the user is either already licensed (URL is a no-op) or in a
        // weird state we don't need to recover from with a popup. The old
        // standalone LicenseSheet was deleted to kill the "two windows" UX bug.
        if onboardingState == nil {
            print("slapshift://license fired without active onboarding — ignoring")
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        if let state = onboardingState, !key.isEmpty {
            state.licenseInputKey = key
            state.activateLicense()
        }
        onboardingWindow?.show()
    }

    // MARK: - Onboarding

    /// Build the OnboardingState, wire its callbacks to real subsystems, and show the window.
    /// The slap pipeline routes the next slap to `onboardingState.testSlapDetected` instead of
    /// firing a mode, so the user can confirm the sensor works without their workspace transforming.
    private func presentOnboarding() {
        let state = OnboardingState()

        // Inject the live accelerometer monitor so the slap-test step can
        // observe recentPeakG directly. Weak reference on the state side
        // keeps the monitor's lifecycle owned by AppDelegate.
        state.motionMonitor = motionMonitor

        // Permission step — open the pane, then poll motion.start() until it succeeds.
        state.openInputMonitoringSettings = { [weak self] in
            self?.openInputMonitoringPane()
            self?.startPermissionPolling()
        }
        // Reflect current permission state immediately — motion may already be running.
        state.permissionGranted = motionRunning

        // Paywall step — "Buy now" routes to Stripe Checkout in the user's
        // browser. Stripe's hosted page is the trusted payment surface, and
        // the redirect back to slapshift://license activates the key once
        // the webhook completes. Email + optional validated promo code
        // (from PaywallStep's Apply flow) are forwarded as query params;
        // /api/checkout flips `allow_promotion_codes` so Stripe shows the
        // promo field on its hosted page where the buyer redeems it.
        state.openCheckout = { [weak state] promoCode in
            let email = state?.email.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let promo = promoCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            var comps = URLComponents(string: "https://slapshift.app/api/checkout")!
            var items: [URLQueryItem] = []
            if !email.isEmpty { items.append(URLQueryItem(name: "email", value: email)) }
            if !promo.isEmpty { items.append(URLQueryItem(name: "promo", value: promo)) }
            if !items.isEmpty { comps.queryItems = items }
            if let url = comps.url {
                NSWorkspace.shared.open(url)
            }
        }

        // Inline paywall activation — buyer pasted a key into the field on
        // the paywall and hit Activate. Calls LicenseManager.tryActivate;
        // on success the existing licenseManager.$state subscription below
        // flips the onboarding step to .activated automatically. On failure
        // surfaces a one-line error under the field.
        state.activateLicense = { [weak self, weak state] in
            guard let self = self, let state = state else { return }
            let key = state.licenseInputKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { return }
            state.licenseActivating = true
            state.licenseActivationError = nil
            Task { @MainActor in
                let result = await self.licenseManager.tryActivate(key: key)
                state.licenseActivating = false
                switch result {
                case .success:
                    state.licenseActivationError = nil
                case .failure(let err):
                    state.licenseActivationError = err.userMessage
                }
            }
        }

        // Onboarding profile capture — fires once when the user advances off
        // the usage step. POSTs name/email/usage to /api/profile so we can
        // add the email to the Resend list even if they bail before paying.
        // Best-effort: failures are logged, never surfaced.
        state.submitProfile = { [weak state] in
            guard let state else { return }
            Self.postOnboardingProfile(
                name: state.name,
                email: state.email,
                usage: Array(state.usage),
                otherDetail: state.otherUsageDetail,
                referralSources: state.referralSources.isEmpty ? nil : Array(state.referralSources),
                calibrationPeakG: state.calibrationPeakG > 0 ? state.calibrationPeakG : nil
            )
        }

        onboardingState = state
        let finish: () -> Void = { [weak self] in
            self?.onboardingComplete = true
            self?.persistOnboardingProfile(state)
            self?.onboardingState = nil
            self?.onboardingWindow = nil
            self?.stopPermissionPolling()
            // Once onboarding is done, re-evaluate whether the menu bar icon
            // should appear. It only appears once they ALSO have a license.
            self?.installMenuBarIfReady()
            // Pop the Willow-style home dashboard so the buyer lands on a
            // real surface (not just a hidden menu-bar app) after closing
            // the onboarding window. This is the post-purchase home base.
            self?.showHome()
            print("Onboarding complete")
        }
        onboardingWindow = OnboardingWindow(state: state, onFinish: finish)
        onboardingWindow?.show()

        // While onboarding is live, watch the LicenseManager. The moment the
        // buyer returns from the Stripe Checkout → /success → slapshift://
        // deep-link round trip and tryActivate flips state to .licensed, we
        // advance the onboarding step from .paywall → .activated so the
        // celebration screen ("Hey, $name. You're all set.") appears
        // automatically without the buyer clicking anything. Guarded on
        // step == .paywall so an unrelated background revalidate doesn't
        // accidentally skip the user through earlier steps.
        licenseManager.$state
            .receive(on: RunLoop.main)
            .sink { [weak self, weak state] newState in
                guard let self = self,
                      let state = state,
                      self.onboardingState === state else { return }
                if newState.isLicensed && state.step == .paywall {
                    state.step = .activated
                }
            }
            .store(in: &cancellables)
    }

    /// Lazily build and show the home window. Reachable from the menu bar
    /// "Show Home" item and called automatically when onboarding finishes.
    private func showHome() {
        if homeWindow == nil {
            homeWindow = HomeWindow(
                modeStore: modeStore,
                motionMonitor: motionMonitor,
                prefs: prefs,
                stats: stats,
                onOpenSettings: { [weak self] in self?.settingsWindow.show() },
                onSignOut: { [weak self] in self?.confirmAndSignOut() }
            )
        }
        homeWindow?.show()
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

    // MARK: - Sign out

    /// Confirm + sign out. Triggered by the menu bar Sign Out item. We surface
    /// an NSAlert before doing anything destructive because clearing the
    /// license cache + onboarding flag drops the user all the way back to
    /// the welcome step. Re-pasting the same key on the same Mac re-activates
    /// instantly (server-side machine_id binding matches the same hardware ID).
    private func confirmAndSignOut() {
        let alert = NSAlert()
        alert.messageText = "Sign out of SlapShift?"
        alert.informativeText = """
            You'll go back through onboarding. Your license key still works \
            on this Mac — paste it again on the paywall to re-activate. Your \
            modes and preferences are kept.
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Sign Out")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }
        signOut()
    }

    /// Reset the app to its pre-onboarding state. Clears the license cache
    /// and the onboarding-complete flag + persisted profile fields, removes
    /// the menu bar icon, closes home/settings windows, then re-presents
    /// onboarding. Modes are intentionally NOT touched — the user may sign
    /// out to switch licenses but keep their hard-earned mode config.
    private func signOut() {
        print("Signing out…")

        // 1. Drop the cached license (keychain) so the paywall fires again.
        licenseManager.deactivate()

        // 2. Forget that onboarding was ever completed + clear persisted
        //    profile so the user can re-enter their email/usage cleanly.
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Self.onboardingCompleteKey)
        defaults.removeObject(forKey: "onboarding.name")
        defaults.removeObject(forKey: "onboarding.email")
        defaults.removeObject(forKey: "onboarding.usage")
        defaults.removeObject(forKey: "onboarding.otherUsageDetail")
        stats.reset()

        // 3. Tear down menu bar so the gate (`installMenuBarIfReady`) holds:
        //    no icon until onboarding done AND licensed.
        if menuBarInstalled {
            menuBar.uninstall()
            menuBarInstalled = false
        }

        // 4. Close the home + settings windows so the only surface is the
        //    onboarding flow again.
        homeWindow?.close()
        homeWindow = nil
        settingsWindow.hide()

        // 5. Re-present onboarding from step one.
        presentOnboarding()
    }

    /// Save the lightweight onboarding profile (name, email, usage tags) to
    /// UserDefaults so it survives relaunch. Email is the durable user handle
    /// for the license + mailing list.
    private func persistOnboardingProfile(_ state: OnboardingState) {
        let defaults = UserDefaults.standard
        defaults.set(state.name, forKey: "onboarding.name")
        defaults.set(state.email, forKey: "onboarding.email")
        defaults.set(Array(state.usage), forKey: "onboarding.usage")
        defaults.set(state.otherUsageDetail, forKey: "onboarding.otherUsageDetail")
    }

    /// POST the onboarding profile to slapshift.app/api/profile, which
    /// upserts into the Supabase `onboarding_profiles` table. Fired from
    /// `OnboardingState.submitProfile` when the user leaves the usage step
    /// (and again after source/slapTest each add new columns).
    /// Best-effort: HTTP failures are logged and swallowed — onboarding
    /// must never block on a server round-trip.
    ///
    /// `referralSources` / `calibrationPeakG` are nil on the first POST
    /// (before those steps have been answered) so we don't blow away later
    /// upserts with empty values — the server's upsert only writes fields
    /// that are present in the payload.
    static func postOnboardingProfile(
        name: String,
        email: String,
        usage: [String],
        otherDetail: String,
        referralSources: [String]? = nil,
        calibrationPeakG: Double? = nil
    ) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else { return }
        guard let url = URL(string: "https://slapshift.app/api/profile") else { return }

        let trimmedOther = otherDetail.trimmingCharacters(in: .whitespacesAndNewlines)
        var payload: [String: Any] = [
            "name": name.trimmingCharacters(in: .whitespacesAndNewlines),
            "email": trimmedEmail,
            "usage": usage,
            "otherDetail": trimmedOther,
        ]
        if let referralSources { payload["referralSources"] = referralSources }
        if let calibrationPeakG { payload["calibrationPeakG"] = calibrationPeakG }
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        req.timeoutInterval = 10

        URLSession.shared.dataTask(with: req) { _, response, error in
            if let error = error {
                print("[profile] POST failed: \(error.localizedDescription)")
                return
            }
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                print("[profile] POST returned \(http.statusCode)")
            }
        }.resume()
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
            // Timer.scheduledTimer's closure is @Sendable under Swift 6, but
            // AppDelegate's state is @MainActor-isolated. Hop back to the main
            // actor so we can touch motionRunning / menuBar / onboardingState
            // without tripping concurrency diagnostics.
            Task { @MainActor in
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
    }

    private func stopPermissionPolling() {
        permissionPollTimer?.invalidate()
        permissionPollTimer = nil
    }

    private func handleSlap(_ event: SlapEvent) {
        // If onboarding is on a demo step (1/2/3 slaps), route the slap into
        // the onboarding state instead of the user's real modes. The demo
        // steps DETECT ONLY — they don't open apps, quit apps, or launch URLs.
        // The point is to teach the gesture and prove the sensor works; the
        // user gets to actually fire modes after they customize and pay. On
        // a mismatch the inline UI shows "you slapped N, try again".
        if let state = onboardingState, let expected = state.step.expectedSlapCount {
            let matched = state.recordDemoSlap(actualCount: event.count)
            print("Onboarding demo: expected \(expected), got \(event.count) — \(matched ? "match" : "mismatch")")
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
        let actionCount = mode.appsToOpen.count + mode.appsToQuit.count + mode.urlsToOpen.count
        stats.recordSlap(actionCount: actionCount)
    }

    func applicationWillTerminate(_ notification: Notification) {
        motion?.stop()
    }
}
