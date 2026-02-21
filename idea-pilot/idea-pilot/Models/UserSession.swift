//
//  UserSession.swift
//  idea-pilot
//
//  Lightweight struct representing the authenticated user's session.
//  Stored in Keychain (not SwiftData) via TokenManager (Issue #7).
//

import Foundation

/// The authenticated user's session data.
///
/// This is a plain value type — not a SwiftData `@Model` — because auth tokens
/// belong in the Keychain, not in the local database. `TokenManager` (Issue #7)
/// will handle serialization and secure storage.
nonisolated struct UserSession: Codable, Sendable, Equatable {

    /// The user's server-assigned identifier.
    let userId: String

    /// The user's email address.
    let email: String

    /// JWT access token for API requests.
    let accessToken: String

    /// Refresh token for obtaining new access tokens.
    let refreshToken: String
}
