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
    var enabled: Bool = true

    // Focus mode integration was removed in v1.0 — Apple's Focus system has
    // no public API and shipping a Shortcuts-based bridge added too much
    // onboarding friction for too little payoff. A future release will
    // bring it back behind a feature flag once the silent-install path is
    // sorted (likely via a System Extension that runs the Set Focus action
    // in the background). Until then, modes are open/quit/URL only.
    //
    // The Codable decode keeps tolerating any extra keys (focusModeName) on
    // disk via Swift's default behavior of ignoring unknown JSON fields, so
    // users upgrading from a previous build don't lose their modes — the
    // focus key is just silently dropped on next save.
}
