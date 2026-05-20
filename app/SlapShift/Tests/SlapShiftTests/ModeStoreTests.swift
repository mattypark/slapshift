// Tests for ModeStore — load/save/round-trip + corruption tolerance.
//
// Uses a tmp directory so we never touch the real ~/Library/Application Support/SlapShift.

import XCTest
@testable import SlapShift

final class ModeStoreTests: XCTestCase {

    private var tempDir: URL!
    private var fileURL: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SlapShiftTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        fileURL = tempDir.appendingPathComponent("modes.json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func test_loadOrSeedDefaults_whenFileMissing_seedsThreeDefaults() {
        let store = ModeStore(fileURL: fileURL)
        store.loadOrSeedDefaults()

        XCTAssertEqual(store.modes.count, 3)
        XCTAssertEqual(store.modes.map { $0.slapCount }.sorted(), [1, 2, 3])
        // Defaults should have been persisted to disk.
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func test_saveAndLoad_roundTrip_preservesEdits() {
        // First store: seed + edit + save.
        let store1 = ModeStore(fileURL: fileURL)
        store1.loadOrSeedDefaults()
        var edited = store1.modes.first { $0.slapCount == 1 }!
        edited.name = "Custom Coding"
        edited.urlsToOpen = ["https://example.com/dashboard"]
        store1.update(edited)

        // Second store: load from same file, edits should be present.
        let store2 = ModeStore(fileURL: fileURL)
        store2.loadOrSeedDefaults()
        let reloaded = store2.modes.first { $0.slapCount == 1 }!
        XCTAssertEqual(reloaded.name, "Custom Coding")
        XCTAssertEqual(reloaded.urlsToOpen, ["https://example.com/dashboard"])
    }

    func test_loadOrSeedDefaults_whenJSONCorrupt_fallsBackToDefaults() {
        // Write garbage to disk.
        try! "not json at all { malformed".write(to: fileURL, atomically: true, encoding: .utf8)

        let store = ModeStore(fileURL: fileURL)
        store.loadOrSeedDefaults()

        // Should fall back to the seeded defaults rather than crash or load empty.
        XCTAssertEqual(store.modes.count, 3)
        XCTAssertEqual(store.modes.map { $0.slapCount }.sorted(), [1, 2, 3])
    }

    func test_loadOrSeedDefaults_whenJSONEmpty_fallsBackToDefaults() {
        // Empty array is technically valid JSON but should not silently leave the user
        // with zero modes. ModeStore checks `!decoded.isEmpty` before accepting.
        try! "[]".write(to: fileURL, atomically: true, encoding: .utf8)

        let store = ModeStore(fileURL: fileURL)
        store.loadOrSeedDefaults()

        XCTAssertEqual(store.modes.count, 3)
    }
}
