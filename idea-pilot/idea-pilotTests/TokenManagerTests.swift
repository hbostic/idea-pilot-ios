//
//  TokenManagerTests.swift
//  idea-pilotTests
//
//  Unit tests for TokenManager with mock Keychain and mock network.
//

import Foundation
import Testing
@testable import idea_pilot

// MARK: - Mock Keychain Service

/// In-memory Keychain replacement for testing.
nonisolated final class MockKeychainService: KeychainStorable, @unchecked Sendable {

    nonisolated(unsafe) var storage: [String: String] = [:]
    nonisolated(unsafe) var saveCallCount = 0
    nonisolated(unsafe) var loadCallCount = 0
    nonisolated(unsafe) var deleteCallCount = 0
    nonisolated(unsafe) var shouldThrowOnSave = false
    nonisolated(unsafe) var shouldThrowOnLoad = false
    nonisolated(unsafe) var shouldThrowOnDelete = false

    func save(_ value: String, forKey key: String) throws {
        saveCallCount += 1
        if shouldThrowOnSave {
            throw KeychainError.unexpectedStatus(-25300)
        }
        storage[key] = value
    }

    func load(forKey key: String) throws -> String? {
        loadCallCount += 1
        if shouldThrowOnLoad {
            throw KeychainError.unexpectedStatus(-25300)
        }
        return storage[key]
    }

    func delete(forKey key: String) throws {
        deleteCallCount += 1
        if shouldThrowOnDelete {
            throw KeychainError.unexpectedStatus(-25300)
        }
        storage.removeValue(forKey: key)
    }
}

// MARK: - Mock URL Protocol (separate from APIClientTests to avoid shared state)

/// A `URLProtocol` subclass for TokenManager tests, independent of `MockURLProtocol`.
final class TokenMockURLProtocol: URLProtocol, @unchecked Sendable {

    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (Data, HTTPURLResponse))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = TokenMockURLProtocol.handler else {
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
    config.protocolClasses = [TokenMockURLProtocol.self]
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

private func makeUserSession() -> UserSession {
    UserSession(
        userId: "user-123",
        email: "test@example.com",
        accessToken: "access-token-abc",
        refreshToken: "refresh-token-xyz"
    )
}

// MARK: - TokenManager Tests

@Suite("TokenManager", .serialized)
struct TokenManagerTests {

    // MARK: - Storage

    @Test("storeSession persists all four fields to Keychain")
    func storeSessionPersists() async throws {
        let keychain = MockKeychainService()
        let manager = TokenManager(keychain: keychain, baseURL: testBaseURL)

        try await manager.storeSession(makeUserSession())

        #expect(keychain.storage["com.lifeautomation.idea-pilot.accessToken"] == "access-token-abc")
        #expect(keychain.storage["com.lifeautomation.idea-pilot.refreshToken"] == "refresh-token-xyz")
        #expect(keychain.storage["com.lifeautomation.idea-pilot.userId"] == "user-123")
        #expect(keychain.storage["com.lifeautomation.idea-pilot.email"] == "test@example.com")
        #expect(keychain.saveCallCount == 4)
    }

    @Test("accessToken returns stored value from cache")
    func accessTokenFromCache() async throws {
        let keychain = MockKeychainService()
        let manager = TokenManager(keychain: keychain, baseURL: testBaseURL)
        try await manager.storeSession(makeUserSession())

        let token = await manager.accessToken
        #expect(token == "access-token-abc")
    }

    @Test("accessToken loads from Keychain on first access")
    func accessTokenLoadsFromKeychain() async {
        let keychain = MockKeychainService()
        keychain.storage["com.lifeautomation.idea-pilot.accessToken"] = "persisted-token"
        keychain.storage["com.lifeautomation.idea-pilot.refreshToken"] = "persisted-refresh"

        let manager = TokenManager(keychain: keychain, baseURL: testBaseURL)
        let token = await manager.accessToken
        #expect(token == "persisted-token")
    }

    @Test("accessToken returns nil when no tokens stored")
    func accessTokenNilWhenEmpty() async {
        let keychain = MockKeychainService()
        let manager = TokenManager(keychain: keychain, baseURL: testBaseURL)

        let token = await manager.accessToken
        #expect(token == nil)
    }

    // MARK: - isAuthenticated

    @Test("isAuthenticated is true after storeSession")
    func isAuthenticatedAfterStore() async throws {
        let keychain = MockKeychainService()
        let manager = TokenManager(keychain: keychain, baseURL: testBaseURL)
        try await manager.storeSession(makeUserSession())

        let authed = await manager.isAuthenticated
        #expect(authed == true)
    }

    @Test("isAuthenticated is false when no tokens")
    func isAuthenticatedWhenEmpty() async {
        let keychain = MockKeychainService()
        let manager = TokenManager(keychain: keychain, baseURL: testBaseURL)

        let authed = await manager.isAuthenticated
        #expect(authed == false)
    }

    @Test("isAuthenticated is false after clearTokens")
    func isAuthenticatedAfterClear() async throws {
        let keychain = MockKeychainService()
        let manager = TokenManager(keychain: keychain, baseURL: testBaseURL)
        try await manager.storeSession(makeUserSession())
        await manager.clearTokens()

        let authed = await manager.isAuthenticated
        #expect(authed == false)
    }

    // MARK: - clearTokens

    @Test("clearTokens removes all four Keychain items and clears cache")
    func clearTokensRemovesAll() async throws {
        let keychain = MockKeychainService()
        let manager = TokenManager(keychain: keychain, baseURL: testBaseURL)
        try await manager.storeSession(makeUserSession())

        await manager.clearTokens()

        #expect(await manager.accessToken == nil)
        #expect(keychain.storage.isEmpty)
        #expect(keychain.deleteCallCount == 4)
    }

    @Test("clearTokens does not throw when Keychain delete fails")
    func clearTokensGracefulOnDeleteFailure() async throws {
        let keychain = MockKeychainService()
        let manager = TokenManager(keychain: keychain, baseURL: testBaseURL)
        try await manager.storeSession(makeUserSession())

        keychain.shouldThrowOnDelete = true
        await manager.clearTokens()

        // Cache should still be cleared even if Keychain delete failed.
        #expect(await manager.accessToken == nil)
    }

    // MARK: - refresh

    @Test("refresh updates tokens on successful API response")
    func refreshSuccess() async throws {
        let keychain = MockKeychainService()
        keychain.storage["com.lifeautomation.idea-pilot.refreshToken"] = "old-refresh"
        keychain.storage["com.lifeautomation.idea-pilot.accessToken"] = "old-access"

        let responseJSON = #"{"access_token":"new-access","refresh_token":"new-refresh","user_id":"user-1","email":"a@b.com"}"#
        TokenMockURLProtocol.handler = { request in
            return (Data(responseJSON.utf8), makeResponse(statusCode: 200))
        }

        let manager = TokenManager(keychain: keychain, baseURL: testBaseURL, session: makeURLSession())

        try await manager.refresh()

        #expect(await manager.accessToken == "new-access")
        #expect(keychain.storage["com.lifeautomation.idea-pilot.accessToken"] == "new-access")
        #expect(keychain.storage["com.lifeautomation.idea-pilot.refreshToken"] == "new-refresh")
        #expect(keychain.storage["com.lifeautomation.idea-pilot.userId"] == "user-1")
        #expect(keychain.storage["com.lifeautomation.idea-pilot.email"] == "a@b.com")
        TokenMockURLProtocol.handler = nil
    }

    @Test("refresh throws noRefreshToken when no refresh token stored")
    func refreshThrowsNoRefreshToken() async {
        let keychain = MockKeychainService()
        let manager = TokenManager(keychain: keychain, baseURL: testBaseURL)

        do {
            try await manager.refresh()
            Issue.record("Expected TokenManagerError.noRefreshToken")
        } catch let error as TokenManagerError {
            guard case .noRefreshToken = error else {
                Issue.record("Expected noRefreshToken, got \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("refresh throws refreshFailed on non-2xx response")
    func refreshThrowsOnServerError() async {
        let keychain = MockKeychainService()
        keychain.storage["com.lifeautomation.idea-pilot.refreshToken"] = "some-refresh"
        keychain.storage["com.lifeautomation.idea-pilot.accessToken"] = "some-access"

        TokenMockURLProtocol.handler = { _ in
            (Data(), makeResponse(statusCode: 401))
        }

        let manager = TokenManager(keychain: keychain, baseURL: testBaseURL, session: makeURLSession())

        do {
            try await manager.refresh()
            Issue.record("Expected TokenManagerError.refreshFailed")
        } catch let error as TokenManagerError {
            guard case .refreshFailed = error else {
                Issue.record("Expected refreshFailed, got \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
        TokenMockURLProtocol.handler = nil
    }

    // MARK: - Keychain Error Handling

    @Test("accessToken returns nil gracefully when Keychain read fails")
    func accessTokenGracefulOnReadFailure() async {
        let keychain = MockKeychainService()
        keychain.shouldThrowOnLoad = true

        let manager = TokenManager(keychain: keychain, baseURL: testBaseURL)
        let token = await manager.accessToken
        #expect(token == nil)
    }

    @Test("storeSession throws when Keychain write fails")
    func storeSessionThrowsOnWriteFailure() async {
        let keychain = MockKeychainService()
        keychain.shouldThrowOnSave = true

        let manager = TokenManager(keychain: keychain, baseURL: testBaseURL)

        do {
            try await manager.storeSession(makeUserSession())
            Issue.record("Expected KeychainError")
        } catch {
            #expect(error is KeychainError)
        }
    }

    // MARK: - userId and email

    @Test("userId and email available after storeSession")
    func userIdAndEmail() async throws {
        let keychain = MockKeychainService()
        let manager = TokenManager(keychain: keychain, baseURL: testBaseURL)
        try await manager.storeSession(UserSession(
            userId: "user-42",
            email: "harold@example.com",
            accessToken: "a",
            refreshToken: "r"
        ))

        #expect(await manager.userId == "user-42")
        #expect(await manager.email == "harold@example.com")
    }

    // MARK: - Persistence Across Instances

    @Test("tokens persist across TokenManager instances (simulated app relaunch)")
    func persistenceAcrossInstances() async throws {
        let keychain = MockKeychainService()

        let manager1 = TokenManager(keychain: keychain, baseURL: testBaseURL)
        try await manager1.storeSession(makeUserSession())

        let manager2 = TokenManager(keychain: keychain, baseURL: testBaseURL)
        let token = await manager2.accessToken
        #expect(token == "access-token-abc")

        let authed = await manager2.isAuthenticated
        #expect(authed == true)
    }
}
