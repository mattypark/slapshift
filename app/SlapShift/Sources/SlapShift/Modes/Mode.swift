// Mode — the unit of "what happens when you slap N times."
//
// Persisted as JSON in ~/Library/Application Support/SlapShift/modes.json.
// Codable so the settings UI can edit, save, reload without ceremony.

import Foundation

struct Mode: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String                    // "Coding", "Apply", "Wind Down"
    var slapCount: Int                  // 1, 2, or 3 — primary key for lookup
    var symbol: String                  // SF Symbol name, e.g. "laptopcomputer"
    var appsToOpen: [String]            // bundle IDs, e.g. "com.microsoft.VSCode"
    var appsToQuit: [String]            // bundle IDs
    var urlsToOpen: [String]            // raw URL strings
    var focusModeName: String?          // exact macOS Focus name, e.g. "Do Not Disturb" (nil = skip)
    var enabled: Bool = true
}
