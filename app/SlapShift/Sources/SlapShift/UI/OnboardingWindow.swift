// OnboardingWindow — NSWindowController that hosts OnboardingView on first run.
//
// Same pattern as SettingsWindow: manual NSWindow because we use a hand-rolled
// NSApplication entry point and want to flip activation policy (.accessory <→ .regular)
// to surface a real window on a menu-bar-only app.

import AppKit
import SwiftUI

final class OnboardingWindow {

    private var window: NSWindow?
    private let state: OnboardingState
    private let onFinish: () -> Void

    init(state: OnboardingState, onFinish: @escaping () -> Void) {
        self.state = state
        self.onFinish = onFinish
    }

    func show() {
        if let existing = window {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let view = OnboardingView(state: state, onFinish: { [weak self] in
            self?.close()
            self?.onFinish()
        })

        let hosting = NSHostingController(rootView: view)
        let win = NSWindow(contentViewController: hosting)
        win.title = "Welcome to SlapShift"
        win.styleMask = [.titled, .closable]
        win.setContentSize(NSSize(width: 560, height: 460))
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
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
