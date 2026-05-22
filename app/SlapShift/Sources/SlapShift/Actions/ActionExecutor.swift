// ActionExecutor — runs a Mode's actions.
//
// Ordering matters for the demo feel:
//   1. Quits first  (clears the desktop)
//   2. Apps open    (the meat of the gesture)
//   3. URLs open    (after apps so the browser is already up)
//
// Each step is non-fatal: if Slack isn't running, the quit is a no-op, not an error.
//
// NOTE: Focus mode integration was removed in v1.0. See Modes/Mode.swift for
// the rationale. A future release will reintroduce it as a background-running
// System Extension once we have time to do it without the onboarding tax.

import AppKit
import Foundation

final class ActionExecutor {

    func execute(_ mode: Mode) {
        quitApps(mode.appsToQuit)
        openApps(mode.appsToOpen)
        openURLs(mode.urlsToOpen)
    }

    // MARK: - Apps

    // Activate the FIRST app in the mode (so the user actually sees their workspace
    // come up), but leave the rest in the background. This avoids focus-stealing
    // mid-mode (e.g. Chrome stealing focus from VSCode 200ms after VSCode opened).
    // The first app is the "anchor" of the mode — usually the editor or browser
    // the user is going to start typing into immediately.
    private func openApps(_ bundleIDs: [String]) {
        for (index, bundleID) in bundleIDs.enumerated() {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
                NSLog("SlapShift: cannot find app \(bundleID) — skipping")
                continue
            }
            let config = NSWorkspace.OpenConfiguration()
            config.activates = (index == 0)
            NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
                if let error = error {
                    NSLog("SlapShift: open \(bundleID) failed: \(error)")
                }
            }
        }
    }

    private func quitApps(_ bundleIDs: [String]) {
        for bundleID in bundleIDs {
            let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            for app in running {
                if !app.terminate() {
                    // terminate() returns false for apps that refused — we don't force-kill
                    NSLog("SlapShift: \(bundleID) refused terminate")
                }
            }
        }
    }

    // MARK: - URLs

    private func openURLs(_ urls: [String]) {
        for str in urls {
            guard let url = URL(string: str) else {
                NSLog("SlapShift: invalid URL \(str)")
                continue
            }
            NSWorkspace.shared.open(url)
        }
    }
}
