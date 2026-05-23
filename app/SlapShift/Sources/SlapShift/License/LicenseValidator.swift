// LicenseValidator — talks to /api/license/validate.
//
// Single endpoint, one POST. Server replies:
//   { ok: true,  expiresAt: "...", email: "..." }            — valid
//   { ok: false, reason: "not_found" | "refunded" | ... }    — invalid
//
// We don't retry on network errors here — the caller (LicenseManager) decides
// whether to fall back to a cached grace window or block the user. Keeping
// retry policy out of this layer makes the failure modes obvious.

import Foundation

struct LicenseValidationOk {
    let expiresAt: Date
    let email: String?
}

enum LicenseValidationFailure: Error, Equatable {
    case notFound
    case refunded
    case machineMismatch
    case rateLimited
    case badRequest
    case serverError
    case network(String)
    case decode
    case unknown(String)

    var userMessage: String {
        switch self {
        case .notFound:        return "We couldn't find that license key. Double-check the email we sent you."
        case .refunded:        return "This license was refunded and is no longer active."
        case .machineMismatch: return "This license is already bound to a different Mac. Email support@slapshift.app to switch machines."
        case .rateLimited:     return "Too many attempts. Wait a minute and try again."
        case .badRequest:      return "That doesn't look like a SlapShift key. Format is SLAP-XXXX-XXXX-…"
        case .serverError:     return "Our server hiccuped. Try again in a moment."
        case .network(let m):  return "Couldn't reach SlapShift. Check your internet. (\(m))"
        case .decode:          return "Got an unexpected response from the server. Try again."
        case .unknown(let r):  return "License rejected (\(r))."
        }
    }
}

enum LicenseValidator {

    /// Base URL for the license API. Override via Info.plist key `SlapShiftAPIBaseURL`
    /// for local development; falls back to production.
    static var baseURL: URL {
        if let override = Bundle.main.object(forInfoDictionaryKey: "SlapShiftAPIBaseURL") as? String,
           let url = URL(string: override) {
            return url
        }
        return URL(string: "https://slapshift.app")!
    }

    static func validate(key: String, machineId: String) async -> Result<LicenseValidationOk, LicenseValidationFailure> {
        let url = baseURL.appendingPathComponent("/api/license/validate")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 15

        let body: [String: String] = ["key": key, "machineId": machineId]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else {
            return .failure(.decode)
        }
        req.httpBody = data

        do {
            let (respData, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                return .failure(.network("no HTTP response"))
            }

            // Both 200 and 4xx return JSON envelopes; we parse regardless and let
            // the `ok` field drive the decision. 5xx is treated as transient.
            if http.statusCode >= 500 {
                return .failure(.serverError)
            }

            guard let json = try JSONSerialization.jsonObject(with: respData) as? [String: Any] else {
                return .failure(.decode)
            }

            if let ok = json["ok"] as? Bool, ok {
                guard let expiresAtStr = json["expiresAt"] as? String,
                      let expiresAt = parseISO8601(expiresAtStr) else {
                    return .failure(.decode)
                }
                let email = json["email"] as? String
                return .success(LicenseValidationOk(expiresAt: expiresAt, email: email))
            }

            let reason = (json["reason"] as? String) ?? "unknown"
            return .failure(map(reason: reason))
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    /// Parse an ISO-8601 timestamp from the server. The server uses
    /// `Date.toISOString()` which ALWAYS emits milliseconds
    /// (e.g. `2026-06-22T15:30:00.123Z`). Apple's default
    /// `ISO8601DateFormatter` parses only to-the-second precision and
    /// returns nil on fractional seconds, so we try the millisecond
    /// variant first and fall back to the plain variant for safety.
    private static func parseISO8601(_ s: String) -> Date? {
        let withMs = ISO8601DateFormatter()
        withMs.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withMs.date(from: s) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: s)
    }

    private static func map(reason: String) -> LicenseValidationFailure {
        switch reason {
        case "not_found":        return .notFound
        case "bad_format":       return .badRequest
        case "refunded":         return .refunded
        case "machine_mismatch": return .machineMismatch
        case "rate_limited":     return .rateLimited
        case "bad_request":      return .badRequest
        case "server_error":     return .serverError
        default:                 return .unknown(reason)
        }
    }
}
