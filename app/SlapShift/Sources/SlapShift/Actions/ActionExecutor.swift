// ActionExecutor — runs a Mode's actions.
//
// Ordering matters for the demo feel:
//   1. Quits first  (clears the desktop)
//   2. Focus mode   (silences notifications before apps spam us)
//   3. Apps open    (the meat of the gesture)
//   4. URLs open    (after apps so the browser is already up)
//
// Each step is non-fatal: if Slack isn't running, the quit is a no-op, not an error.

import AppKit
import Foundation

final class ActionExecutor {

    func execute(_ mode: Mode) {
        quitApps(mode.appsToQuit)
        if let focus = mode.focusModeName { enterFocus(focus) }
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

    // MARK: - Focus mode (via Shortcuts CLI)
    //
    // macOS has no public API to set a Focus directly, but Shortcuts can ("Set Focus" action).
    // The first-run installer creates one shortcut per Focus name: "SlapShift: Set Focus to X".
    // Here we just shell out to `shortcuts run`. Non-fatal if the shortcut doesn't exist.

    private func enterFocus(_ name: String) {
        let shortcutName = "SlapShift: Set Focus to \(name)"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", shortcutName]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            NSLog("SlapShift: shortcuts run failed for '\(shortcutName)': \(error)")
        }
        // Don't wait — fire and forget. If the shortcut takes 2s the rest of the mode shouldn't block.
    }
}
