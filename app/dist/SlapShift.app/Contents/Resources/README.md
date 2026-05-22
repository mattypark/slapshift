# DefaultShortcuts — reserved (currently unused)

As of v0.1, SlapShift installs default Focus-helper shortcuts via **iCloud Links**,
not bundled `.shortcut` files. The list lives in
`Sources/SlapShift/Focus/ShortcutInstaller.swift` (`defaultShortcutURLs`).

### Why iCloud Links instead of bundled files?

macOS Sequoia removed "Save as File" from the Shortcuts.app share menu. Apple's
sanctioned modern path is iCloud Link sharing, generated via right-click →
**Share → Copy iCloud Link**. Either approach surfaces the same add-confirmation
UI on the user's Mac.

iCloud links are strictly cleaner for SlapShift's case:
- No bundle resource shipping
- No "drag the .shortcut file into the project" build step
- Works on any Mac with internet
- Updating the defaults is a one-line code change, not a re-bundle

### Replacing the default shortcuts

1. Create or edit the shortcut in Shortcuts.app.
2. Right-click the shortcut → **Share** → **Copy iCloud Link**.
3. Edit `Sources/SlapShift/Focus/ShortcutInstaller.swift`, replace the matching
   URL in `defaultShortcutURLs`.
4. Rebuild.

### Why does this directory still exist?

xcodegen's `project.yml` references it as a copyFiles destination. If we ever
want to bundle real `.shortcut` files alongside the iCloud-link flow (e.g.,
for offline-friendly installs), we can drop them here and re-add the file
enumeration to `ShortcutInstaller`. Until then, this directory is reserved.
