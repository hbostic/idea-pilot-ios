//
//  AuthServiceTests.swift
//  idea-pilotTests
//
//  Unit tests for AuthService with mock networking and in-memory SwiftData.
//

import Foundation
import SwiftData
import Testing
@testable import idea_pilot

// MARK: - Mock URL Protocol (independent from other test suites)

/// A `URLProtocol` subclass for AuthService tests, independent of other mocks.
final class AuthServiceMockURLProtocol: URLProtocol, @unchecked Sendable {

    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (Data, HTTPURLResponse))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = AuthServiceMockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }

        do {
            let (data, response) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Test Helpers

private let testBaseURL = URL(string: "https://api.test.ideapilot.app")!

private func makeURLSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [AuthServiceMockURLProtocol.self]
    return URLSession(configuration: config)
}

private nonisolated func makeResponse(statusCode: Int) -> HTTPURLResponse {
    HTTPURLResponse(
        url: testBaseURL,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: nil
    )!
}

private let successTokensJSON = #"""
{
    "tokens": {
        "access_token": "new-access",
        "refresh_token": "new-refresh"
    },
    "user": {
        "id": "user-1",
        "email": "test@example.com"
    }
}
"""#

private nonisolated func makeInMemoryModelContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: PlaybookModel.self, TaskModel.self, SectionModel.self, WeeklyCycleModel.self,
        configurations: config
    )
}

private nonisolated func makeAuthService(
    keychain: MockKeychainService = MockKeychainService(),
    session: URLSession? = nil
) throws -> (AuthService, TokenManager, MockKeychainService, ModelContainer) {
    let urlSession = session ?? makeURLSession()
    let tokenManager = TokenManager(keychain: keychain, baseURL: testBaseURL, session: urlSession)
    let apiClient = APIClient(baseURL: testBaseURL, session: urlSession, tokenProvider: tokenManager)
    let container = try makeInMemoryModelContainer()
    let authService = AuthService(apiClient: apiClient, tokenManager: tokenManager, modelContainer: container)
    return (authService, tokenManager, keychain, container)
}

// MARK: - AuthService Tests

@Suite("AuthService", .serialized)
struct AuthServiceTests {

    // MARK: - Login

    @Test("login success stores session and returns UserSession")
    func loginSuccess() async throws {
        AuthServiceMockURLProtocol.handler = { _ in
            (Data(successTokensJSON.utf8), makeResponse(statusCode: 200))
        }

        let (authService, tokenManager, _, _) = try makeAuthService()

        let session = try await authService.login(email: "test@example.com", password: "password123")

        #expect(session.userId == "user-1")
        #expect(session.email == "test@example.com")
        #expect(session.accessToken == "new-access")
        #expect(session.refreshToken == "new-refresh")

        let storedToken = await tokenManager.accessToken
        #expect(storedToken == "new-access")

        AuthServiceMockURLProtocol.handler = nil
    }

    @Test("login with invalid credentials throws invalidCredentials")
    func loginInvalidCredentials() async throws {
        AuthServiceMockURLProtocol.handler = { _ in
            (Data(), makeResponse(statusCode: 401))
        }

        let (authService, _, _, _) = try makeAuthService()

        do {
            _ = try await authService.login(email: "wrong@example.com", password: "bad")
            Issue.record("Expected AuthError.invalidCredentials")
        } catch let error as AuthError {
            #expect(error == .invalidCredentials)
        }

        AuthServiceMockURLProtocol.handler = nil
    }

    // MARK: - Register

    @Test("register success stores session and returns UserSession")
    func registerSuccess() async throws {
        AuthServiceMockURLProtocol.handler = { _ in
            (Data(successTokensJSON.utf8), makeResponse(statusCode: 200))
        }

        let (authService, tokenManager, _, _) = try makeAuthService()

        let session = try await authService.register(email: "new@example.com", password: "password123")

        #expect(session.userId == "user-1")
        #expect(session.accessToken == "new-access")

        let storedToken = await tokenManager.accessToken
        #expect(storedToken == "new-access")

        AuthServiceMockURLProtocol.handler = nil
    }

    @Test("register with existing email throws emailAlreadyExists")
    func registerEmailAlreadyExists() async throws {
        let errorJSON = #"{"error":{"code":"CONFLICT","message":"A user with this email already exists"}}"#
        AuthServiceMockURLProtocol.handler = { _ in
            (Data(errorJSON.utf8), makeResponse(statusCode: 409))
        }

        let (authService, _, _, _) = try makeAuthService()

        do {
            _ = try await authService.register(email: "taken@example.com", password: "password123")
            Issue.record("Expected AuthError.emailAlreadyExists")
        } catch let error as AuthError {
            #expect(error == .emailAlreadyExists)
        }

        AuthServiceMockURLProtocol.handler = nil
    }

    // MARK: - Auth0 Login

    @Test("auth0Login success stores session and returns UserSession")
    func auth0LoginSuccess() async throws {
        AuthServiceMockURLProtocol.handler = { _ in
            (Data(successTokensJSON.utf8), makeResponse(statusCode: 200))
        }

        let (authService, tokenManager, _, _) = try makeAuthService()

        let session = try await authService.auth0Login(idToken: "auth0-id-token-xyz")

        #expect(session.userId == "user-1")
        #expect(session.email == "test@example.com")
        #expect(session.accessToken == "new-access")

        let storedToken = await tokenManager.accessToken
        #expect(storedToken == "new-access")

        AuthServiceMockURLProtocol.handler = nil
    }

    // MARK: - Logout

    @Test("logout clears tokens and SwiftData")
    func logoutClearsState() async throws {
        // Set up authenticated state.
        let keychain = MockKeychainService()
        AuthServiceMockURLProtocol.handler = { _ in
            (Data(), makeResponse(statusCode: 200))
        }

        let (authService, tokenManager, _, container) = try makeAuthService(keychain: keychain)

        // Store a session first.
        try await tokenManager.storeSession(UserSession(
            userId: "user-1",
            email: "test@example.com",
            accessToken: "access-token",
            refreshToken: "refresh-token"
        ))

        // Add a playbook to SwiftData.
        let context = await container.mainContext
        let playbook = PlaybookModel(id: "pb-1", title: "Test Playbook")
        await context.insert(playbook)
        try await context.save()

        try await authService.logout()

        let token = await tokenManager.accessToken
        #expect(token == nil)

        let isAuthed = await tokenManager.isAuthenticated
        #expect(isAuthed == false)

        AuthServiceMockURLProtocol.handler = nil
    }

    @Test("logout clears local state even if API call fails")
    func logoutClearsStateOnNetworkFailure() async throws {
        let keychain = MockKeychainService()
        AuthServiceMockURLProtocol.handler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let (authService, tokenManager, _, _) = try makeAuthService(keychain: keychain)

        // Store a session first.
        try await tokenManager.storeSession(UserSession(
            userId: "user-1",
            email: "test@example.com",
            accessToken: "access-token",
            refreshToken: "refresh-token"
        ))

        try await authService.logout()

        let token = await tokenManager.accessToken
        #expect(token == nil)

        AuthServiceMockURLProtocol.handler = nil
    }

    // MARK: - Error Mapping

    @Test("login offline error mapped to AuthError.offline")
    func loginOfflineError() async throws {
        AuthServiceMockURLProtocol.handler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let (authService, _, _, _) = try makeAuthService()

        do {
            _ = try await authService.login(email: "test@example.com", password: "pass")
            Issue.record("Expected AuthError.offline")
        } catch let error as AuthError {
            guard case .offline = error else {
                Issue.record("Expected offline, got \(error)")
                return
            }
        }

        AuthServiceMockURLProtocol.handler = nil
    }

    @Test("login network error (non-offline) mapped to AuthError.networkError")
    func loginNetworkError() async throws {
        AuthServiceMockURLProtocol.handler = { _ in
            throw URLError(.cannotConnectToHost)
        }

        let (authService, _, _, _) = try makeAuthService()

        do {
            _ = try await authService.login(email: "test@example.com", password: "pass")
            Issue.record("Expected AuthError.networkError")
        } catch let error as AuthError {
            guard case .networkError = error else {
                Issue.record("Expected networkError, got \(error)")
                return
            }
        }

        AuthServiceMockURLProtocol.handler = nil
    }

    @Test("register server error mapped to AuthError.serverError")
    func registerServerError() async throws {
        let errorJSON = #"{"message":"Internal server error"}"#
        AuthServiceMockURLProtocol.handler = { _ in
            (Data(errorJSON.utf8), makeResponse(statusCode: 500))
        }

        let (authService, _, _, _) = try makeAuthService()

        do {
            _ = try await authService.register(email: "test@example.com", password: "pass")
            Issue.record("Expected AuthError.serverError")
        } catch let error as AuthError {
            guard case .serverError = error else {
                Issue.record("Expected serverError, got \(error)")
                return
            }
        }

        AuthServiceMockURLProtocol.handler = nil
    }

    @Test("login sends correct endpoint path and method")
    func loginEndpointCorrect() async throws {
        nonisolated(unsafe) var capturedPath: String?
        nonisolated(unsafe) var capturedMethod: String?

        AuthServiceMockURLProtocol.handler = { request in
            capturedPath = request.url?.path
            capturedMethod = request.httpMethod
            return (Data(successTokensJSON.utf8), makeResponse(statusCode: 200))
        }

        let (authService, _, _, _) = try makeAuthService()
        _ = try await authService.login(email: "test@example.com", password: "pass")

        #expect(capturedPath?.contains("/v1/auth/login") == true)
        #expect(capturedMethod == "POST")

        AuthServiceMockURLProtocol.handler = nil
    }
}
