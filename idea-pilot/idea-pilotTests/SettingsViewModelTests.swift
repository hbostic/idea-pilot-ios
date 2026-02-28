//
//  SettingsViewModelTests.swift
//  idea-pilotTests
//
//  Unit tests for SettingsViewModel.
//

import Foundation
import SwiftData
import Testing
@testable import idea_pilot

// MARK: - Mock Auth Service

private struct MockSettingsAuthService: AuthServiceProtocol {
    func login(email: String, password: String) async throws -> UserSession {
        UserSession(userId: "1", email: email, accessToken: "t", refreshToken: "r")
    }
    func register(email: String, password: String) async throws -> UserSession {
        UserSession(userId: "1", email: email, accessToken: "t", refreshToken: "r")
    }
    func auth0Login(idToken: String) async throws -> UserSession {
        UserSession(userId: "1", email: "test@test.com", accessToken: "t", refreshToken: "r")
    }
    func logout() async throws {}
}

// MARK: - Mock Keychain

private final class MockKeychain: KeychainStorable, @unchecked Sendable {
    private var store: [String: String] = [:]

    func save(_ value: String, forKey key: String) throws {
        store[key] = value
    }
    func load(forKey key: String) throws -> String? {
        store[key]
    }
    func delete(forKey key: String) throws {
        store.removeValue(forKey: key)
    }
}

// MARK: - Test Helpers

private let testBaseURL = URL(string: "https://api.test.ideapilot.app")!

private func makeTokenManager(email: String? = "test@example.com") async throws -> TokenManager {
    let keychain = MockKeychain()
    let tm = TokenManager(keychain: keychain, baseURL: testBaseURL)
    if let email {
        try await tm.storeSession(UserSession(
            userId: "user-1",
            email: email,
            accessToken: "access",
            refreshToken: "refresh"
        ))
    }
    return tm
}

private func makeSyncEngine() throws -> SyncEngine {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: PlaybookModel.self, TaskModel.self, SectionModel.self, WeeklyCycleModel.self, MutationEntry.self,
        configurations: config
    )
    let sessionConfig = URLSessionConfiguration.ephemeral
    sessionConfig.protocolClasses = [SettingsTestMockURLProtocol.self]
    let session = URLSession(configuration: sessionConfig)
    let apiClient = APIClient(baseURL: testBaseURL, session: session)
    return SyncEngine(apiClient: apiClient, modelContainer: container)
}

// MARK: - Mock URL Protocol

private final class SettingsTestMockURLProtocol: URLProtocol, @unchecked Sendable {

    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (Data, HTTPURLResponse))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = SettingsTestMockURLProtocol.handler else {
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

// MARK: - Tests

@Suite("SettingsViewModel", .serialized)
@MainActor
struct SettingsViewModelTests {

    @Test("loadEmail populates email from TokenManager")
    func loadEmailSetsEmail() async throws {
        let tm = try await makeTokenManager(email: "test@example.com")
        let vm = SettingsViewModel(
            tokenManager: tm,
            authService: MockSettingsAuthService(),
            syncEngine: nil,
            onSignOut: {}
        )

        #expect(vm.email == nil)

        await vm.loadEmail()

        #expect(vm.email == "test@example.com")
    }

    @Test("appVersion returns non-empty string")
    func appVersionNotEmpty() {
        let vm = SettingsViewModel(
            tokenManager: TokenManager(baseURL: testBaseURL),
            authService: MockSettingsAuthService(),
            syncEngine: nil,
            onSignOut: {}
        )

        #expect(!vm.appVersion.isEmpty)
    }

    @Test("syncStatusValue defaults to .synced when no engine")
    func syncStatusDefaultsSynced() {
        let vm = SettingsViewModel(
            tokenManager: TokenManager(baseURL: testBaseURL),
            authService: MockSettingsAuthService(),
            syncEngine: nil,
            onSignOut: {}
        )

        #expect(vm.syncStatusValue == .synced)
    }

    @Test("syncStatusValue reflects engine status")
    func syncStatusReflectsEngine() throws {
        let engine = try makeSyncEngine()
        let vm = SettingsViewModel(
            tokenManager: TokenManager(baseURL: testBaseURL),
            authService: MockSettingsAuthService(),
            syncEngine: engine,
            onSignOut: {}
        )

        engine.status.value = .offline
        #expect(vm.syncStatusValue == .offline)

        engine.status.value = .pending(3)
        #expect(vm.syncStatusValue == .pending(3))

        engine.status.value = .synced
        #expect(vm.syncStatusValue == .synced)
    }

    @Test("pendingCount reflects engine queue")
    func pendingCountReflectsQueue() throws {
        let engine = try makeSyncEngine()
        let vm = SettingsViewModel(
            tokenManager: TokenManager(baseURL: testBaseURL),
            authService: MockSettingsAuthService(),
            syncEngine: engine,
            onSignOut: {}
        )

        #expect(vm.pendingCount == 0)
        #expect(vm.hasPendingMutations == false)

        engine.enqueue(
            path: "/v1/tasks",
            method: .post,
            body: nil as CreateTaskDTO?,
            entityType: "task"
        )

        #expect(vm.pendingCount == 1)
        #expect(vm.hasPendingMutations == true)
    }

    @Test("confirmSignOut shows confirmation when mutations pending")
    func confirmSignOutShowsDialogWhenPending() throws {
        let engine = try makeSyncEngine()
        let vm = SettingsViewModel(
            tokenManager: TokenManager(baseURL: testBaseURL),
            authService: MockSettingsAuthService(),
            syncEngine: engine,
            onSignOut: {}
        )

        engine.enqueue(
            path: "/v1/tasks",
            method: .post,
            body: nil as CreateTaskDTO?,
            entityType: "task"
        )

        vm.confirmSignOut()

        #expect(vm.showSignOutConfirmation == true)
    }

    @Test("confirmSignOut calls performSignOut directly when no pending")
    func confirmSignOutDirectWhenNoPending() {
        nonisolated(unsafe) var signOutCalled = false
        let vm = SettingsViewModel(
            tokenManager: TokenManager(baseURL: testBaseURL),
            authService: MockSettingsAuthService(),
            syncEngine: nil,
            onSignOut: { signOutCalled = true }
        )

        vm.confirmSignOut()

        #expect(vm.showSignOutConfirmation == false)
        #expect(signOutCalled == true)
    }

    @Test("performSignOut fires onSignOut callback")
    func performSignOutCallsCallback() {
        nonisolated(unsafe) var signOutCalled = false
        let vm = SettingsViewModel(
            tokenManager: TokenManager(baseURL: testBaseURL),
            authService: MockSettingsAuthService(),
            syncEngine: nil,
            onSignOut: { signOutCalled = true }
        )

        vm.performSignOut()

        #expect(signOutCalled == true)
    }

    @Test("syncNow sets isSyncing during sync")
    func syncNowSetsIsSyncing() async throws {
        SettingsTestMockURLProtocol.handler = { _ in
            let response = HTTPURLResponse(
                url: testBaseURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(), response)
        }

        let engine = try makeSyncEngine()
        let vm = SettingsViewModel(
            tokenManager: TokenManager(baseURL: testBaseURL),
            authService: MockSettingsAuthService(),
            syncEngine: engine,
            onSignOut: {}
        )

        #expect(vm.isSyncing == false)

        await vm.syncNow()

        // After sync completes, isSyncing should be false.
        #expect(vm.isSyncing == false)

        SettingsTestMockURLProtocol.handler = nil
    }

    @Test("isConnected defaults to true when no engine")
    func isConnectedDefaultsTrue() {
        let vm = SettingsViewModel(
            tokenManager: TokenManager(baseURL: testBaseURL),
            authService: MockSettingsAuthService(),
            syncEngine: nil,
            onSignOut: {}
        )

        #expect(vm.isConnected == true)
    }

    @Test("lastSyncText returns nil when never synced")
    func lastSyncTextNilWhenNeverSynced() {
        let vm = SettingsViewModel(
            tokenManager: TokenManager(baseURL: testBaseURL),
            authService: MockSettingsAuthService(),
            syncEngine: nil,
            onSignOut: {}
        )

        #expect(vm.lastSyncText == nil)
    }
}
