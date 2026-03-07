//
//  AuthService.swift
//  idea-pilot
//
//  Orchestrates authentication flows: login, registration, Auth0, and logout.
//

import Foundation
import SwiftData

// MARK: - AuthError

/// Errors specific to authentication operations.
nonisolated enum AuthError: Error, Equatable, Sendable {
    /// Email/password combination is incorrect (401 on login).
    case invalidCredentials
    /// The email is already registered (400 with "already exists").
    case emailAlreadyExists
    /// The device has no internet connection.
    case offline
    /// A network-level failure occurred (server unreachable, timeout, DNS, etc.).
    case networkError(String)
    /// The server returned an unexpected error.
    case serverError(String)
}

// MARK: - AuthServiceProtocol

/// Defines the authentication API surface for testability.
nonisolated protocol AuthServiceProtocol: Sendable {
    func login(email: String, password: String) async throws -> UserSession
    func register(email: String, password: String) async throws -> UserSession
    func auth0Login(idToken: String) async throws -> UserSession
    func logout() async throws
}

// MARK: - AuthService

/// Coordinates authentication flows through `APIClient` and `TokenManager`.
///
/// Each sign-in method (email/password, Auth0) follows the same pattern:
/// 1. Call the API endpoint
/// 2. Store the resulting session in TokenManager
/// 3. Return the `UserSession`
///
/// Logout performs a best-effort server call, then always clears local state
/// (tokens + SwiftData) regardless of network outcome.
final class AuthService: AuthServiceProtocol, Sendable {

    private let apiClient: APIClient
    private let tokenManager: TokenManager
    private let modelContainer: ModelContainer

    /// Creates an AuthService.
    ///
    /// - Parameters:
    ///   - apiClient: The networking client for API calls.
    ///   - tokenManager: Manages token storage and refresh.
    ///   - modelContainer: The SwiftData container for clearing local data on logout.
    init(apiClient: APIClient, tokenManager: TokenManager, modelContainer: ModelContainer) {
        self.apiClient = apiClient
        self.tokenManager = tokenManager
        self.modelContainer = modelContainer
    }

    func login(email: String, password: String) async throws -> UserSession {
        let dto = LoginRequestDTO(email: email, password: password)
        do {
            let response: AuthResponseDTO = try await apiClient.request(.login(dto: dto))
            let session = response.toUserSession()
            try await tokenManager.storeSession(session)
            return session
        } catch let error as APIError {
            throw mapAuthError(error, context: .login)
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.serverError(error.localizedDescription)
        }
    }

    func register(email: String, password: String) async throws -> UserSession {
        let dto = RegisterRequestDTO(email: email, password: password)
        do {
            let response: AuthResponseDTO = try await apiClient.request(.register(dto: dto))
            let session = response.toUserSession()
            try await tokenManager.storeSession(session)
            return session
        } catch let error as APIError {
            throw mapAuthError(error, context: .register)
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.serverError(error.localizedDescription)
        }
    }

    func auth0Login(idToken: String) async throws -> UserSession {
        let dto = Auth0RequestDTO(idToken: idToken)
        do {
            let response: AuthResponseDTO = try await apiClient.request(.auth0(dto: dto))
            let session = response.toUserSession()
            try await tokenManager.storeSession(session)
            return session
        } catch let error as APIError {
            throw mapAuthError(error, context: .auth0)
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.serverError(error.localizedDescription)
        }
    }

    func logout() async throws {
        // Best-effort server-side token invalidation.
        try? await apiClient.requestVoid(.logout())

        // Always clear local state regardless of server response.
        await tokenManager.clearTokens()
        try await clearLocalData()
    }

    // MARK: - Private

    private enum AuthContext {
        case login, register, auth0
    }

    private func mapAuthError(_ error: APIError, context: AuthContext) -> AuthError {
        switch error {
        case .sessionExpired:
            return .invalidCredentials
        case .badRequest(let message):
            if context == .register,
               let msg = message?.lowercased(),
               msg.contains("already") || msg.contains("exists") {
                return .emailAlreadyExists
            }
            return .serverError(message ?? "Bad request")
        case .networkError(let urlError):
            return .networkError(urlError.localizedDescription)
        case .offline:
            return .offline
        case .notFound:
            return .serverError("Endpoint not found")
        case .serverError(_, let message):
            return .serverError(message ?? "Server error")
        case .decodingError(let message):
            return .serverError("Invalid response: \(message)")
        }
    }

    @MainActor
    private func clearLocalData() throws {
        let context = modelContainer.mainContext
        try context.delete(model: PlaybookModel.self)
    }
}
