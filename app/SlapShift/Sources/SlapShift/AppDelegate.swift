// AppDelegate — the seam between motion events and mode execution.
//
// Owns: the menu bar controller, the mode store, the motion stack, the executor.
// Does: wire the slap callback to (look up mode by count) → (execute) → (flash icon).

import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let modeStore = ModeStore()
    private let executor = ActionExecutor()
    private var menuBar: MenuBarController!
    private var motion: MotionPoller!
    private var classifier: SlapClassifier!

    func applicationDidFinishLaunching(_ notification: Notification) {
        modeStore.loadOrSeedDefaults()

        menuBar = MenuBarController(modeStore: modeStore)
        menuBar.onQuit = { NSApp.terminate(nil) }
        menuBar.install()

        classifier = SlapClassifier()
        classifier.onSlap = { [weak self] event in
            self?.handleSlap(event)
        }

        motion = MotionPoller()
        motion.onSample = { [weak self] sample in
            self?.classifier.ingest(sample)
        }

        do {
            try motion.start()
            menuBar.setState(.armed)
        } catch {
            NSLog("SlapShift: motion start failed: \(error)")
            menuBar.setState(.error(error.localizedDescription))
        }
    }

    private func handleSlap(_ event: SlapEvent) {
        // Instant UX feedback: flash before action fires so user knows the slap registered.
        menuBar.flash()

        guard let mode = modeStore.mode(forSlapCount: event.count) else {
            NSLog("SlapShift: no mode bound to \(event.count) slap(s) — ignoring")
            return
        }

        NSLog("SlapShift: \(event.count) slap(s) @ \(String(format: "%.2fg", event.peakG)) → mode '\(mode.name)'")
        executor.execute(mode)
    }

    func applicationWillTerminate(_ notification: Notification) {
        motion?.stop()
    }
}
