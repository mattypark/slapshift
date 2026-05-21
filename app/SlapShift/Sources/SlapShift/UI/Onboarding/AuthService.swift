// AuthService — abstraction over Sign in with Google / Apple.
//
// PHASE 1 (current): stub implementation. Tapping "Continue with Google" or
// "Continue with Apple" runs a short fake delay and returns a placeholder
// `AuthIdentity`. The point is to ship the full UI flow today so we can test
// the entire onboarding click-through before the dashboard side (Supabase
// auth providers + Google Cloud OAuth client + Apple Sign-in Services ID)
// is wired up. The user still types their own email on the welcome step so
// the rest of the flow has real data to work with.
//
// PHASE 2 (next): swap StubAuthService for SupabaseAuthService, which uses
// `ASWebAuthenticationSession` to open the Supabase OAuth URL for the chosen
// provider, catches the slapshift://auth/callback redirect, and exchanges the
// PKCE code for a session. The public surface (signIn(provider:) -> AuthIdentity)
// stays identical so the SwiftUI views don't change.

import Foundation

enum AuthProvider: String, Codable {
    case google
    case apple

    var displayName: String {
        switch self {
        case .google: return "Google"
        case .apple:  return "Apple"
        }
    }
}

struct AuthIdentity: Codable, Equatable {
    /// Stable user id. In Phase 2 this becomes the Supabase auth.user.id (UUID).
    var userId: String
    var email: String
    var displayName: String?
    var provider: AuthProvider
}

enum AuthError: LocalizedError {
    case cancelled
    case stubFailure(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:           return "Sign in was cancelled."
        case .stubFailure(let m):  return m
        }
    }
}

@MainActor
protocol AuthService {
    func signIn(with provider: AuthProvider) async throws -> AuthIdentity
}

/// Phase 1 stub. Returns a deterministic-looking fake identity after a short
/// "connecting…" delay so the UI feels real during click-throughs.
///
/// Why a delay at all: without it the screen flashes through "Connecting…"
/// faster than the user can register it, which makes the sign-in step feel
/// broken. 900ms is the sweet spot — long enough to read the label, short
/// enough that it doesn't feel laggy.
@MainActor
final class StubAuthService: AuthService {

    func signIn(with provider: AuthProvider) async throws -> AuthIdentity {
        try await Task.sleep(nanoseconds: 900_000_000)
        // The email here is a stub. The next onboarding step (the "name" /
        // welcome confirmation) collects the real address from the user, and
        // the paywall step uses that for the Stripe checkout pre-fill.
        return AuthIdentity(
            userId: "stub-" + UUID().uuidString,
            email: "you@example.com",
            displayName: nil,
            provider: provider
        )
    }
}
