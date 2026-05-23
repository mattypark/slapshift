// HomeWindow — NSWindowController that hosts the Willow-style home dashboard.
//
// Opens automatically after the post-purchase ActivatedStep, and is also
// reachable from the menu bar "Show Home" item. Same NSWindow pattern as
// OnboardingWindow/SettingsWindow — manual window construction because the
// app uses a hand-rolled NSApplication entry point and toggles activation
// policy between .accessory (menu-bar-only) and .regular (real window
// surfaced + Dock icon + app menu).
//
// Lifecycle:
//   show()  → activation policy = .regular, makeKeyAndOrderFront
//   close() → window dismissed, WindowDelegate.windowWillClose flips policy
//             back to .accessory so the app returns to menu-bar-only mode.

import AppKit
import SwiftUI

final class HomeWindow {

    private var window: NSWindow?
    private let modeStore: ModeStore
    private let motionMonitor: MotionMonitor
    private let prefs: AppPreferences
    private let onOpenSettings: () -> Void

    init(modeStore: ModeStore,
         motionMonitor: MotionMonitor,
         prefs: AppPreferences,
         onOpenSettings: @escaping () -> Void) {
        self.modeStore = modeStore
        self.motionMonitor = motionMonitor
        self.prefs = prefs
        self.onOpenSettings = onOpenSettings
    }

    func show() {
        if let existing = window {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let view = HomeView(
            modeStore: modeStore,
            motionMonitor: motionMonitor,
            prefs: prefs,
            onOpenSettings: onOpenSettings
        )

        let hosting = NSHostingController(rootView: view)
        let win = NSWindow(contentViewController: hosting)
        win.title = "SlapShift"
        // Same titlebar treatment as OnboardingWindow: transparent + hidden
        // title so the cream background bleeds under the traffic lights and
        // the window reads as a single sheet of paper.
        win.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        win.collectionBehavior.insert(.fullScreenPrimary)
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.backgroundColor = NSColor(red: 0.925, green: 0.898, blue: 0.820, alpha: 1)
        win.setContentSize(NSSize(width: 820, height: 640))
        win.minSize = NSSize(width: 640, height: 520)
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = WindowDelegate.shared

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        window = win
    }

    func close() {
        window?.close()
        window = nil
    }

    private final class WindowDelegate: NSObject, NSWindowDelegate {
        static let shared = WindowDelegate()
        func windowWillClose(_ notification: Notification) {
            // Return to menu-bar-only mode when the home window is dismissed.
            // Without this the Dock icon would linger after the user hits the
            // red traffic-light close button.
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
