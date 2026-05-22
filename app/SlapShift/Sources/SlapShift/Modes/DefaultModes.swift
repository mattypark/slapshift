// DefaultModes — the three modes that ship pre-configured.
//
// Per CEO review §3: first-run is "slap and feel it work", not "configure for 30 min".
// Users edit these; they don't build modes from scratch in v1.

import Foundation

enum DefaultModes {

    static func seed() -> [Mode] {
        return [coding(), apply(), windDown()]
    }

    private static func coding() -> Mode {
        Mode(
            name: "Coding",
            slapCount: 1,
            symbol: "chevron.left.forwardslash.chevron.right",
            appsToOpen: [
                "com.microsoft.VSCode",
                "com.todesktop.230313mzl4w4u92",  // Cursor
                "com.google.Chrome",
                "com.apple.Terminal"
            ],
            appsToQuit: [
                "com.tinyspeck.slackmacgap",      // Slack
                "com.hnc.Discord"
            ],
            urlsToOpen: [
                "http://localhost:3000"
            ]
        )
    }

    private static func apply() -> Mode {
        Mode(
            name: "Apply",
            slapCount: 2,
            symbol: "graduationcap",
            appsToOpen: [
                "com.google.Chrome"
            ],
            appsToQuit: [
                "com.spotify.client"
            ],
            urlsToOpen: [
                "https://apply.commonapp.org",
                "https://www.stanford.edu/admission",
                "https://college.harvard.edu/admissions",
                "https://admission.princeton.edu",
                "https://admissions.yale.edu",
                "https://admissions.mit.edu"
            ]
        )
    }

    private static func windDown() -> Mode {
        Mode(
            name: "Wind Down",
            slapCount: 3,
            symbol: "moon.stars",
            appsToOpen: [
                "com.spotify.client",
                "com.apple.Notes"
            ],
            appsToQuit: [
                "com.microsoft.VSCode",
                "com.todesktop.230313mzl4w4u92",
                "com.apple.Terminal",
                "com.tinyspeck.slackmacgap"
            ],
            urlsToOpen: []
        )
    }
}
