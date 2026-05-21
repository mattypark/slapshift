// LicenseStore — Keychain-backed cache of an activated license.
//
// What we cache:
//   key         — plaintext SLAP-XXXX-XXXX-... (so we can re-validate later)
//   email       — buyer email (displayed in Settings, helps support)
//   machineId   — what we used when binding, lets us detect re-bind drift
//   validatedAt — last successful server check
//   expiresAt   — server-issued offline grace (typically now + 30 days)
//
// Why Keychain not UserDefaults:
//   Keychain entries are encrypted at rest and survive app reinstalls. They
//   also can't be copied between machines as easily — minor piracy speed bump.
//
// Service name is namespaced so multiple apps from the same developer don't
// collide. We store the whole record as a single JSON blob (one Keychain
// item to fetch, easy to update atomically).

import Foundation
import Security

struct LicenseRecord: Codable, Equatable {
    var key: String
    var email: String?
    var machineId: String
    var validatedAt: Date
    var expiresAt: Date

    /// True if the cached validation is still within its server-issued grace window.
    var isWithinGrace: Bool {
        Date() < expiresAt
    }
}

enum LicenseStore {

    private static let service = "com.matthewpark.slapshift.license"
    private static let account = "primary"

    static func load() -> LicenseRecord? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return try? JSONDecoder.iso8601.decode(LicenseRecord.self, from: data)
    }

    @discardableResult
    static func save(_ record: LicenseRecord) -> Bool {
        guard let data = try? JSONEncoder.iso8601.encode(record) else { return false }

        // Upsert: delete first (ignore not-found), then add. Simpler than
        // SecItemUpdate's two-step dance and avoids subtle attribute mismatches.
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    @discardableResult
    static func clear() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

private extension JSONEncoder {
    static let iso8601: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

private extension JSONDecoder {
    static let iso8601: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
