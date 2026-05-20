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
//   Settings...             (opens settings window — v2 stub for Weekend 3)
//   Test 1 slap             (fires the slap callback manually so the user can verify wiring)
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
        statusItem.menu = buildMenu()
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

    // MARK: - Menu

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

        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))

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

        // Wire target for items that use self
        for item in menu.items where item.action == #selector(openSettings) {
            item.target = self
        }
        return menu
    }

    @objc private func openSettings() {
        // Weekend 3 wires the real settings window. For now: open the JSON in default editor.
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let modesFile = support.appendingPathComponent("SlapShift/modes.json")
        NSWorkspace.shared.open(modesFile)
    }

    @objc private func testSlap(_ sender: NSMenuItem) {
        onTestSlap?(sender.tag)
    }

    @objc private func quit() {
        onQuit?()
    }

    // MARK: - Icons
    //
    // We use SF Symbols templated to the menu bar tint. The flash state inverts to a filled
    // variant for ~180ms so the user gets sub-perceptual confirmation that the slap landed.

    private static func icon(for state: State) -> NSImage? {
        let name: String
        switch state {
        case .armed:           name = "hand.tap"
        case .flash:           name = "hand.tap.fill"
        case .error:           name = "exclamationmark.triangle"
        }
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "SlapShift")
        image?.isTemplate = true
        return image
    }
}
