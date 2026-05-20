// ModeStore — load/save modes from ~/Library/Application Support/SlapShift/modes.json.
//
// ObservableObject so SwiftUI views observe edits and re-render. Saves on every mutation
// (modes are small, JSON write is microseconds, no point batching).

import Combine
import Foundation

final class ModeStore: ObservableObject {

    @Published private(set) var modes: [Mode] = []

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

    /// Binding-style mutation used by SwiftUI. Replace the mode at index with mutated copy.
    func binding(for id: UUID) -> (get: () -> Mode?, set: (Mode) -> Void) {
        return (
            { [weak self] in self?.modes.first { $0.id == id } },
            { [weak self] mode in self?.update(mode) }
        )
    }

    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(modes)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("SlapShift: ModeStore save failed: \(error)")
        }
    }
}
