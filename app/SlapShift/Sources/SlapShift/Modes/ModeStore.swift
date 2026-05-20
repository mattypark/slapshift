// ModeStore — load/save modes from ~/Library/Application Support/SlapShift/modes.json.
//
// Why a file, not UserDefaults: modes are explicit user data; we want them human-readable,
// portable (export/import in v1.1), and not subject to plist quirks. JSON is the right floor.

import Foundation

final class ModeStore {

    private(set) var modes: [Mode] = []

    private let fileURL: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("SlapShift", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("modes.json")
    }

    func loadOrSeedDefaults() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([Mode].self, from: data),
           !decoded.isEmpty
        {
            modes = decoded
            return
        }
        modes = DefaultModes.seed()
        save()
    }

    func mode(forSlapCount count: Int) -> Mode? {
        return modes.first { $0.slapCount == count && $0.enabled }
    }

    func update(_ mode: Mode) {
        if let idx = modes.firstIndex(where: { $0.id == mode.id }) {
            modes[idx] = mode
            save()
        }
    }

    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(modes)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("SlapShift: ModeStore save failed: \(error)")
        }
    }
}
