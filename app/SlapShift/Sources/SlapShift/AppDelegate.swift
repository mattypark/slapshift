// AppDelegate — the seam between motion events and mode execution.
//
// Owns: menu bar controller, mode store, motion stack, executor, settings window, prefs.
// Does: wire the slap callback to (look up mode by count) → (execute) → (flash icon).
//       Bind the sensitivity slider to the live SlapClassifier threshold.

import AppKit
import Combine
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let modeStore = ModeStore()
    private let executor = ActionExecutor()
    private let prefs = AppPreferences.shared
    private var menuBar: MenuBarController!
    private var motion: MotionPoller!
    private var classifier: SlapClassifier!
    private var settingsWindow: SettingsWindow!
    private var cancellables: Set<AnyCancellable> = []

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
        classifier.onSlap = { [weak self] event in
            self?.handleSlap(event)
        }

        // Live-bind the sensitivity slider to the classifier threshold.
        prefs.$slapThresholdG
            .sink { [weak self] newValue in
                self?.classifier.slapThresholdG = newValue
            }
            .store(in: &cancellables)

        motion = MotionPoller()
        motion.onSample = { [weak self] sample in
            self?.classifier.ingest(sample)
        }

        do {
            try motion.start()
            menuBar.setState(.armed)
            print("Motion poller started — slap your MacBook to fire a mode")
            print("Open Settings from the menu bar icon to customize modes")
        } catch {
            print("ERROR: motion start failed: \(error.localizedDescription)")
            print("  → likely Input Monitoring permission needed. Check System Settings.")
            menuBar.setState(.error(error.localizedDescription))
        }
    }

    private func handleSlap(_ event: SlapEvent) {
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

    func applicationWillTerminate(_ notification: Notification) {
        motion?.stop()
    }
}
