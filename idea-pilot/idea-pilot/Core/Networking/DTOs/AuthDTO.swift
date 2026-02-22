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

/// Response from token refresh endpoint (flat format).
nonisolated struct AuthTokensDTO: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let userId: String
    let email: String
}

/// Response from login, register, and auth0 endpoints (nested format).
nonisolated struct AuthResponseDTO: Codable, Sendable {
    let tokens: Tokens
    let user: User

    nonisolated struct Tokens: Codable, Sendable {
        let accessToken: String
        let refreshToken: String
    }

    nonisolated struct User: Codable, Sendable {
        let id: String
        let email: String
    }
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

    /// Converts the flat token response into a `UserSession` for Keychain storage.
    nonisolated func toUserSession() -> UserSession {
        UserSession(
            userId: userId,
            email: email,
            accessToken: accessToken,
            refreshToken: refreshToken
        )
    }
}

extension AuthResponseDTO {

    /// Converts the nested auth response into a `UserSession` for Keychain storage.
    nonisolated func toUserSession() -> UserSession {
        UserSession(
            userId: user.id,
            email: user.email,
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken
        )
    }
}
