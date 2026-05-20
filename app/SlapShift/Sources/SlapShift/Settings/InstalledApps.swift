// InstalledApps — enumerate every .app bundle the user has installed.
//
// Scans /Applications, /Applications/Utilities, /System/Applications, ~/Applications.
// Reads Info.plist for the canonical bundle ID and display name. Pulls the icon via NSWorkspace.
//
// Returned list is cached for the lifetime of the picker sheet. macOS may have hundreds of apps;
// the scan takes ~50-150ms on a typical SSD, so we don't want to re-scan on every keystroke.

import AppKit
import Foundation

struct InstalledApp: Identifiable, Hashable {
    let id: String           // bundle identifier (primary key)
    let name: String         // display name from Info.plist
    let path: String         // absolute path to .app bundle
    var bundleID: String { id }

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: path)
    }
}

enum InstalledApps {

    static func list() -> [InstalledApp] {
        let searchPaths = [
            "/Applications",
            "/Applications/Utilities",
            "/System/Applications",
            "/System/Applications/Utilities",
            NSString(string: "~/Applications").expandingTildeInPath
        ]

        var byBundleID: [String: InstalledApp] = [:]

        for dir in searchPaths {
            let url = URL(fileURLWithPath: dir)
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: url, includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            ) else { continue }

            for appURL in contents where appURL.pathExtension == "app" {
                guard let info = readInfoPlist(at: appURL),
                      let bundleID = info["CFBundleIdentifier"] as? String
                else { continue }

                let name = (info["CFBundleDisplayName"] as? String)
                    ?? (info["CFBundleName"] as? String)
                    ?? appURL.deletingPathExtension().lastPathComponent

                // First occurrence wins (preserves /Applications over /System/Applications for duplicates)
                if byBundleID[bundleID] == nil {
                    byBundleID[bundleID] = InstalledApp(
                        id: bundleID,
                        name: name,
                        path: appURL.path
                    )
                }
            }
        }

        return byBundleID.values.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    private static func readInfoPlist(at appURL: URL) -> [String: Any]? {
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(
                from: data, options: [], format: nil
              ) as? [String: Any]
        else { return nil }
        return plist
    }

    /// Resolve a bundle ID to a display name + icon for showing in the mode editor.
    static func resolve(bundleID: String) -> InstalledApp? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        let info = readInfoPlist(at: url) ?? [:]
        let name = (info["CFBundleDisplayName"] as? String)
            ?? (info["CFBundleName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent
        return InstalledApp(id: bundleID, name: name, path: url.path)
    }
}
