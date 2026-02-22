//
//  TokenProviding.swift
//  idea-pilot
//
//  Protocol for token access and refresh.
//  Concrete implementation: TokenManager (Issue #7).
//

import Foundation

/// Provides access tokens and refresh capability to `APIClient`.
///
/// `APIClient` uses this protocol to inject Bearer tokens into requests
/// and to transparently refresh expired tokens on 401 responses.
///
/// The concrete implementation (`TokenManager`, Issue #7) will handle
/// Keychain storage and the refresh endpoint call.
protocol TokenProviding: Sendable {

    /// The current access token, or `nil` if the user is not authenticated.
    var accessToken: String? { get async }

    /// Attempts to refresh the access token using the stored refresh token.
    ///
    /// - Throws: If the refresh token is invalid or the refresh request fails.
    func refresh() async throws

    /// Clears all stored tokens (sign-out).
    func clearTokens() async
}
