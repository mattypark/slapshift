// MenuBarController — the NSStatusItem that lives in the menu bar.
//
// States:
//   .armed             listening for slaps, default icon
//   .flash             100ms inverted-icon flash right after a slap (instant feedback)
//   .error(reason)     red dot + tooltip; mode action wiring still works if motion is alive
//
// Menu:
//   ⚡ SlapShift (header, disabled)
//   ---
//   1 slap → Coding         (preview, disabled, shows current mode binding)
//   2 slaps → Apply
//   3 slaps → Wind Down
//   ---
//   Settings...
//   Test ▶
//   ---
//   Quit SlapShift

import AppKit

final class MenuBarController {

    enum State {
        case armed
        case flash
        case error(String)
    }

    var onQuit: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onOpenHome: (() -> Void)?
    var onTestSlap: ((Int) -> Void)?
    var onSignOut: (() -> Void)?
    /// Triggers Sparkle's manual update check. Wired in AppDelegate to the
    /// AutoUpdater so users with menu-bar-only workflows don't have to dig
    /// into the main menu.
    var onCheckForUpdates: (() -> Void)?

    private let modeStore: ModeStore
    private var statusItem: NSStatusItem?
    private var flashTimer: Timer?

    init(modeStore: ModeStore) {
        self.modeStore = modeStore
    }

    func install() {
        // Allow re-install after a Sign Out → re-onboard cycle by lazily
        // creating the status item each time the gate (`installMenuBarIfReady`)
        // is satisfied.
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        }
        if let button = statusItem?.button {
            button.image = Self.icon(for: .armed)
            button.toolTip = "SlapShift — listening for slaps"
        }
        rebuildMenu()
    }

    /// Remove the status item from the menu bar. Used by Sign Out so the
    /// menu bar disappears while the user is back in onboarding — matches
    /// `installMenuBarIfReady`'s gate (no icon unless onboarding done AND
    /// licensed). Safe to call when nothing is installed.
    func uninstall() {
        flashTimer?.invalidate()
        flashTimer = nil
        guard let item = statusItem else { return }
        item.menu = nil
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
    }

    func setState(_ state: State) {
        guard let button = statusItem?.button else { return }
        button.image = Self.icon(for: state)
        switch state {
        case .armed:
            button.toolTip = "SlapShift — listening"
        case .flash:
            button.toolTip = "Slap!"
        case .error(let reason):
            button.toolTip = "SlapShift — \(reason)"
        }
    }

    func flash() {
        setState(.flash)
        flashTimer?.invalidate()
        flashTimer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: false) { [weak self] _ in
            self?.setState(.armed)
        }
    }

    /// Rebuilds the menu so mode names reflect the current ModeStore. Called on launch
    /// and whenever the user edits a mode in the settings window.
    func rebuildMenu() {
        statusItem?.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let header = NSMenuItem(title: "SlapShift", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        for count in 1...3 {
            let mode = modeStore.mode(forSlapCount: count)
            let title = "\(count) slap\(count > 1 ? "s" : "") → \(mode?.name ?? "(unset)")"
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
        menu.addItem(.separator())

        let home = NSMenuItem(title: "Show Home", action: #selector(openHome), keyEquivalent: "h")
        home.target = self
        menu.addItem(home)

        let settings = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let testMenu = NSMenu(title: "Test")
        for count in 1...3 {
            let item = NSMenuItem(
                title: "Fire \(count) slap\(count > 1 ? "s" : "")",
                action: #selector(testSlap(_:)),
                keyEquivalent: ""
            )
            item.tag = count
            item.target = self
            testMenu.addItem(item)
        }
        let testParent = NSMenuItem(title: "Test", action: nil, keyEquivalent: "")
        testParent.submenu = testMenu
        menu.addItem(testParent)
        menu.addItem(.separator())

        let checkUpdates = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        checkUpdates.target = self
        menu.addItem(checkUpdates)
        menu.addItem(.separator())

        let signOut = NSMenuItem(title: "Sign Out…", action: #selector(signOut), keyEquivalent: "")
        signOut.target = self
        menu.addItem(signOut)

        let quit = NSMenuItem(title: "Quit SlapShift", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func openHome() {
        onOpenHome?()
    }

    @objc private func testSlap(_ sender: NSMenuItem) {
        onTestSlap?(sender.tag)
    }

    @objc private func quit() {
        onQuit?()
    }

    @objc private func signOut() {
        onSignOut?()
    }

    @objc private func checkForUpdates() {
        onCheckForUpdates?()
    }

    // MARK: - Icons

    private static func icon(for state: State) -> NSImage? {
        let name: String
        switch state {
        case .armed: name = "hand.tap"
        case .flash: name = "hand.tap.fill"
        case .error: name = "exclamationmark.triangle"
        }
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "SlapShift")
        image?.isTemplate = true
        return image
    }
}
