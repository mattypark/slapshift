// SettingsWindow — NSWindowController that hosts the SwiftUI SettingsView.
//
// We don't use SwiftUI's Settings scene because our app uses a manual NSApplication entry point
// (no @main App). Hand-rolling the NSWindow lets us control activation behavior precisely:
// when the user clicks "Settings..." we want the app to come forward as a regular window,
// not stay as a faceless background process.

import AppKit
import SwiftUI

final class SettingsWindow {

    private var window: NSWindow?
    private let modeStore: ModeStore
    private let prefs: AppPreferences

    init(modeStore: ModeStore, prefs: AppPreferences) {
        self.modeStore = modeStore
        self.prefs = prefs
    }

    func show() {
        if let existing = window {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let view = SettingsView()
            .environmentObject(modeStore)
            .environmentObject(prefs)

        let hosting = NSHostingController(rootView: view)
        let win = NSWindow(contentViewController: hosting)
        win.title = "SlapShift Settings"
        win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        win.setContentSize(NSSize(width: 640, height: 780))
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = WindowDelegate.shared

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        window = win
    }

    /// Called when the settings window closes — flip back to .accessory so we go back to
    /// menu-bar-only mode (no Dock icon).
    private final class WindowDelegate: NSObject, NSWindowDelegate {
        static let shared = WindowDelegate()
        func windowWillClose(_ notification: Notification) {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
