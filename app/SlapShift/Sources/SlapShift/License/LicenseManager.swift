// LicenseManager — single source of truth for license state.
//
//  state machine (simplified):
//
//                ┌────────────────┐
//      launch ──►│   .unknown     │
//                └───────┬────────┘
//                        │ on launch: try Keychain
//             ┌──────────┴──────────┐
//             │                     │
//             ▼                     ▼
//       no record found        record found
//             │                     │
//             ▼                     ▼
//       .unlicensed         within grace? ──yes──► .licensed(record)
//                                  │
//                                  no
//                                  ▼
//                          revalidate online ──ok──► .licensed(record)
//                                  │
//                                  fail
//                                  ▼
//                           .unlicensed
//
// The Settings UI + paywall sheet both bind to `state` to render correctly.
// `tryActivate(key:)` is the only path that introduces a new license; it
// blocks on the network so the sheet can show the error inline.

import Combine
import Foundation

enum LicenseState: Equatable {
    case unknown                  // before first load
    case unlicensed               // no key, or last attempt failed
    case licensed(LicenseRecord)  // valid, within grace
    case validating               // mid-network-call, briefly shown in UI

    var isLicensed: Bool {
        if case .licensed = self { return true }
        return false
    }

    var record: LicenseRecord? {
        if case .licensed(let r) = self { return r }
        return nil
    }
}

@MainActor
final class LicenseManager: ObservableObject {

    @Published private(set) var state: LicenseState = .unknown

    /// Re-validate at most this often when the app is left running.
    private let revalidationInterval: TimeInterval = 60 * 60 * 24 * 7 // 7 days

    // MARK: - Boot

    /// Called once on app launch. Loads the Keychain record and decides whether
    /// to trust it (within grace) or force a re-validation.
    func bootstrap() async {
        guard let record = LicenseStore.load() else {
            state = .unlicensed
            return
        }
        if record.isWithinGrace {
            state = .licensed(record)
            // Best-effort revalidate in the background if it's been a while.
            if Date().timeIntervalSince(record.validatedAt) > revalidationInterval {
                Task { await self.revalidate(silently: true) }
            }
            return
        }
        // Grace expired — must talk to the server before we trust the cache.
        state = .validating
        let result = await LicenseValidator.validate(key: record.key, machineId: record.machineId)
        switch result {
        case .success(let ok):
            let updated = LicenseRecord(
                key: record.key,
                email: ok.email ?? record.email,
                machineId: record.machineId,
                validatedAt: Date(),
                expiresAt: ok.expiresAt
            )
            LicenseStore.save(updated)
            state = .licensed(updated)
        case .failure:
            // Server says no; drop the record so we don't loop.
            LicenseStore.clear()
            state = .unlicensed
        }
    }

    // MARK: - Activation

    /// Called from the in-app paywall and from the slapshift:// URL handler.
    /// On success, the record is persisted and `state` flips to `.licensed`.
    func tryActivate(key rawKey: String) async -> Result<LicenseRecord, LicenseValidationFailure> {
        // Aggressively strip anything that isn't [A-Z0-9] before sending. Gmail
        // and other webmail clients routinely smuggle zero-width spaces,
        // non-breaking spaces, and en/em-dashes into the clipboard when users
        // copy styled monospace text — keeping those would make the server
        // reject a perfectly valid key as `bad_format`. Server does the same
        // normalization, but doing it here too means the network round-trip
        // can't be poisoned by a weird codepoint.
        let upper = rawKey.uppercased()
        let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        let stripped = String(upper.unicodeScalars.compactMap { scalar -> Character? in
            let s = String(scalar)
            return s.count == 1 && allowed.contains(Character(s)) ? Character(s) : nil
        })
        // Re-insert canonical hyphens so the server sees the same shape the
        // user pasted. The server strips them again anyway, but this keeps
        // logs and any future format checks consistent.
        let key: String
        if stripped.hasPrefix("SLAP") && stripped.count == 32 {
            let body = stripped.dropFirst(4)
            let groups = stride(from: 0, to: body.count, by: 4).map { offset -> String in
                let start = body.index(body.startIndex, offsetBy: offset)
                let end = body.index(start, offsetBy: min(4, body.count - offset))
                return String(body[start..<end])
            }
            key = "SLAP-" + groups.joined(separator: "-")
        } else {
            key = stripped
        }
        state = .validating
        let machineId = MachineId.current
        let result = await LicenseValidator.validate(key: key, machineId: machineId)
        switch result {
        case .success(let ok):
            let record = LicenseRecord(
                key: key,
                email: ok.email,
                machineId: machineId,
                validatedAt: Date(),
                expiresAt: ok.expiresAt
            )
            LicenseStore.save(record)
            state = .licensed(record)
            return .success(record)
        case .failure(let err):
            // Don't clobber an existing valid license on a transient failure.
            if let existing = LicenseStore.load(), existing.isWithinGrace {
                state = .licensed(existing)
            } else {
                state = .unlicensed
            }
            return .failure(err)
        }
    }

    // MARK: - Background revalidation

    /// Quietly refresh the cached record. Used opportunistically after bootstrap.
    /// Silently fails — if we can't reach the server we keep using the grace window.
    func revalidate(silently: Bool) async {
        guard case .licensed(let record) = state else { return }
        let result = await LicenseValidator.validate(key: record.key, machineId: record.machineId)
        if case .success(let ok) = result {
            let updated = LicenseRecord(
                key: record.key,
                email: ok.email ?? record.email,
                machineId: record.machineId,
                validatedAt: Date(),
                expiresAt: ok.expiresAt
            )
            LicenseStore.save(updated)
            state = .licensed(updated)
            return
        }
        // On failure: only deactivate if the server explicitly said the license is bad.
        // Network errors leave the grace cache in place.
        if case .failure(let err) = result {
            switch err {
            case .notFound, .refunded, .machineMismatch:
                LicenseStore.clear()
                state = .unlicensed
            default:
                break // keep grace
            }
        }
        _ = silently
    }

    // MARK: - Deactivate

    func deactivate() {
        LicenseStore.clear()
        state = .unlicensed
    }
}
