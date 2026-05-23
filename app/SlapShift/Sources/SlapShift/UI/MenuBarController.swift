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

    private let modeStore: ModeStore
    private let statusItem: NSStatusItem
    private var flashTimer: Timer?

    init(modeStore: ModeStore) {
        self.modeStore = modeStore
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    }

    func install() {
        if let button = statusItem.button {
            button.image = Self.icon(for: .armed)
            button.toolTip = "SlapShift — listening for slaps"
        }
        rebuildMenu()
    }

    func setState(_ state: State) {
        guard let button = statusItem.button else { return }
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
        statusItem.menu = buildMenu()
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
