// ShortcutCatalog — enumerates the Focus-helper shortcuts the user has installed.
//
// macOS gives third-party apps NO public API to read the list of Focus modes
// (that data lives in ~/Library/DoNotDisturb/DB/ behind Full Disk Access, which
// is too heavy a permission ask for v1).
//
// What we CAN do is read the list of shortcuts the user has, then filter for
// the ones SlapShift uses: shortcuts named "SlapShift: Set Focus to <name>".
// The user installs these once (either via OnboardingView's "Install Shortcuts"
// step, or by hand). Whatever's installed is what shows up in the picker.
//
// This is self-consistent: ActionExecutor.enterFocus(_:) runs the shortcut
// `"SlapShift: Set Focus to \(name)"`. If the picker only offers names that
// have matching shortcuts, the runtime can't fail to find one.

import Foundation

enum ShortcutCatalog {

    static let prefix = "SlapShift: Set Focus to "

    /// Returns the list of Focus names for which the user has installed a
    /// matching `SlapShift: Set Focus to X` shortcut.
    ///
    /// Synchronous. Spawns `/usr/bin/shortcuts list` and parses stdout.
    /// Returns an empty array if the binary isn't there, the process fails,
    /// or no matching shortcuts are installed.
    static func availableFocusNames() -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["list"]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            NSLog("SlapShift: shortcuts list failed: \(error)")
            return []
        }

        guard process.terminationStatus == 0 else { return [] }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        return parse(output)
    }

    /// Pure parser, exposed for tests. Takes the raw stdout of `shortcuts list`,
    /// returns the Focus-name suffixes of any line beginning with the prefix.
    static func parse(_ output: String) -> [String] {
        return output
            .split(separator: "\n")
            .map(String.init)
            .compactMap { line -> String? in
                guard line.hasPrefix(prefix) else { return nil }
                return String(line.dropFirst(prefix.count))
            }
            .sorted()
    }
}
