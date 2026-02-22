//
//  AuthDTO.swift
//  idea-pilot
//
//  Data transfer objects for authentication endpoints.
//

import Foundation

/// Request body for `POST /v1/auth/login`.
nonisolated struct LoginRequestDTO: Codable, Sendable {
    let email: String
    let password: String
}

/// Response from login and token refresh endpoints.
nonisolated struct AuthTokensDTO: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let userId: String
    let email: String
}

/// Request body for `POST /v1/auth/register`.
nonisolated struct RegisterRequestDTO: Codable, Sendable {
    let email: String
    let password: String
}

/// Request body for `POST /v1/auth/auth0`.
nonisolated struct Auth0RequestDTO: Codable, Sendable {
    let idToken: String
}

/// Request body for `POST /v1/auth/refresh`.
nonisolated struct RefreshTokenRequestDTO: Codable, Sendable {
    let refreshToken: String
}

// MARK: - Mapping

extension AuthTokensDTO {

    /// Converts the auth response into a `UserSession` for Keychain storage.
    nonisolated func toUserSession() -> UserSession {
        UserSession(
            userId: userId,
            email: email,
            accessToken: accessToken,
            refreshToken: refreshToken
        )
    }
}
