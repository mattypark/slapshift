// ShortcutInstaller — opens the three default Focus-helper iCloud shortcut links.
//
// How it works:
//   - Each link points to a shortcut in Apple's iCloud Shortcuts gallery
//   - NSWorkspace.shared.open(URL) routes through macOS, which opens the link
//     in Shortcuts.app and presents the standard "Add Shortcut" confirmation UI
//   - One tap per shortcut to accept; only happens once
//
// Why iCloud links instead of bundled .shortcut files?
//   macOS Sequoia removed "Save as File" from the Shortcuts share menu.
//   The sanctioned modern path is iCloud Links, generated via Share → Copy iCloud Link.
//   No public API to inject a shortcut silently; the add dialog is unavoidable
//   either way, so iCloud links are strictly cleaner — no bundle resource shipping,
//   works on any Mac with internet.
//
// If the user is offline on first run, the links fail to open. That's acceptable:
// onboarding shipping shortcuts isn't safety-critical, and the Focus picker
// gracefully no-ops with helpful guidance when no shortcuts are installed.

import AppKit
import Foundation

enum ShortcutInstaller {

    /// iCloud Links for the three default SlapShift Focus-helper shortcuts.
    /// Each one is a single `Set Focus` action; the user taps "Add Shortcut" once.
    /// To replace the defaults, generate new shortcuts in Shortcuts.app,
    /// right-click → Share → Copy iCloud Link, and paste the new URLs here.
    private static let defaultShortcutURLs: [URL] = [
        // SlapShift: Set Focus to Sleep
        URL(string: "https://www.icloud.com/shortcuts/a1f252ee3dd74cd382d26e4f31f90b01")!,
        // SlapShift: Set Focus to Personal
        URL(string: "https://www.icloud.com/shortcuts/72534dbe274a47b385af8d112c060776")!,
        // SlapShift: Set Focus to Do Not Disturb
        URL(string: "https://www.icloud.com/shortcuts/c1fe4ccd8760418485be04cc6c95223d")!,
    ]

    /// Opens every default Focus-helper shortcut iCloud Link.
    /// Each call to `open` routes the URL to Shortcuts.app, which surfaces the
    /// add-confirmation UI. Returns the count of links attempted.
    @discardableResult
    static func installBundledShortcuts() -> Int {
        for url in defaultShortcutURLs {
            NSWorkspace.shared.open(url)
        }
        return defaultShortcutURLs.count
    }
}
