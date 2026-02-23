//
//  APIClientTests.swift
//  idea-pilotTests
//
//  Unit tests for APIClient, Endpoint, DTOs, and error handling.
//

import Foundation
import Testing
@testable import idea_pilot

// MARK: - Mock URL Protocol

/// A `URLProtocol` subclass that intercepts network requests for testing.
final class MockURLProtocol: URLProtocol, @unchecked Sendable {

    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (Data, HTTPURLResponse))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.handler else {
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

// MARK: - Mock Token Provider

/// A mock `TokenProviding` implementation for testing auth behavior.
final class MockTokenProvider: TokenProviding, @unchecked Sendable {
    nonisolated(unsafe) var _accessToken: String?
    nonisolated(unsafe) var refreshCalled = false
    nonisolated(unsafe) var refreshShouldFail = false
    nonisolated(unsafe) var newTokenAfterRefresh: String?
    nonisolated(unsafe) var clearCalled = false

    nonisolated var accessToken: String? {
        get async { _accessToken }
    }

    nonisolated func refresh() async throws {
        refreshCalled = true
        if refreshShouldFail {
            throw APIError.sessionExpired
        }
        if let newToken = newTokenAfterRefresh {
            _accessToken = newToken
        }
    }

    nonisolated func clearTokens() async {
        clearCalled = true
        _accessToken = nil
    }
}

// MARK: - Test Helpers

private let testBaseURL = URL(string: "https://api.test.ideapilot.app")!

private func makeTestSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
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

/// A simple Codable struct for test responses.
nonisolated struct TestItem: Codable, Sendable, Equatable {
    let id: String
    let name: String
}

// MARK: - APIClient Tests

@Suite("APIClient", .serialized)
struct APIClientTests {

    @Test("successful GET decodes typed response")
    func successfulGet() async throws {
        let json = #"[{"id":"1","name":"Test"}]"#
        MockURLProtocol.handler = { _ in
            (Data(json.utf8), makeResponse(statusCode: 200))
        }

        let client = APIClient(baseURL: testBaseURL, session: makeTestSession())
        let items: [TestItem] = try await client.request(
            Endpoint(path: "/v1/test", method: .get, requiresAuth: false)
        )

        #expect(items == [TestItem(id: "1", name: "Test")])
        MockURLProtocol.handler = nil
    }

    @Test("successful POST sends body and decodes response")
    func successfulPost() async throws {
        let responseJSON = #"{"id":"new-1","name":"Created"}"#
        nonisolated(unsafe) var capturedMethod: String?
        nonisolated(unsafe) var capturedContentType: String?

        MockURLProtocol.handler = { request in
            capturedMethod = request.httpMethod
            capturedContentType = request.value(forHTTPHeaderField: "Content-Type")
            return (Data(responseJSON.utf8), makeResponse(statusCode: 201))
        }

        let client = APIClient(baseURL: testBaseURL, session: makeTestSession())
        let item: TestItem = try await client.request(
            Endpoint(
                path: "/v1/test",
                method: .post,
                body: TestItem(id: "new-1", name: "Created"),
                requiresAuth: false
            )
        )

        #expect(item.id == "new-1")
        #expect(capturedMethod == "POST")
        #expect(capturedContentType == "application/json")
        MockURLProtocol.handler = nil
    }

    @Test("Bearer token injected in Authorization header")
    func bearerTokenInjected() async throws {
        let json = #"{"id":"1","name":"Test"}"#
        nonisolated(unsafe) var capturedAuth: String?

        MockURLProtocol.handler = { request in
            capturedAuth = request.value(forHTTPHeaderField: "Authorization")
            return (Data(json.utf8), makeResponse(statusCode: 200))
        }

        let tokenProvider = MockTokenProvider()
        tokenProvider._accessToken = "test-token-123"

        let client = APIClient(baseURL: testBaseURL, session: makeTestSession(), tokenProvider: tokenProvider)
        let _: TestItem = try await client.request(
            Endpoint(path: "/v1/test", method: .get)
        )

        #expect(capturedAuth == "Bearer test-token-123")
        MockURLProtocol.handler = nil
    }

    @Test("no auth header when tokenProvider is nil")
    func noAuthHeaderWithoutProvider() async throws {
        let json = #"{"id":"1","name":"Test"}"#
        nonisolated(unsafe) var capturedAuth: String?

        MockURLProtocol.handler = { request in
            capturedAuth = request.value(forHTTPHeaderField: "Authorization")
            return (Data(json.utf8), makeResponse(statusCode: 200))
        }

        let client = APIClient(baseURL: testBaseURL, session: makeTestSession())
        let _: TestItem = try await client.request(
            Endpoint(path: "/v1/test", method: .get)
        )

        #expect(capturedAuth == nil)
        MockURLProtocol.handler = nil
    }

    @Test("401 triggers refresh and retry")
    func refreshAndRetry() async throws {
        let successJSON = #"{"id":"1","name":"Refreshed"}"#
        nonisolated(unsafe) var callCount = 0

        MockURLProtocol.handler = { _ in
            callCount += 1
            if callCount == 1 {
                return (Data(), makeResponse(statusCode: 401))
            }
            return (Data(successJSON.utf8), makeResponse(statusCode: 200))
        }

        let tokenProvider = MockTokenProvider()
        tokenProvider._accessToken = "expired-token"
        tokenProvider.newTokenAfterRefresh = "fresh-token"

        let client = APIClient(baseURL: testBaseURL, session: makeTestSession(), tokenProvider: tokenProvider)
        let item: TestItem = try await client.request(
            Endpoint(path: "/v1/test", method: .get)
        )

        #expect(item.name == "Refreshed")
        #expect(tokenProvider.refreshCalled)
        #expect(callCount == 2)
        MockURLProtocol.handler = nil
    }

    @Test("401 with failed refresh throws sessionExpired")
    func failedRefreshThrowsSessionExpired() async throws {
        MockURLProtocol.handler = { _ in
            (Data(), makeResponse(statusCode: 401))
        }

        let tokenProvider = MockTokenProvider()
        tokenProvider._accessToken = "expired-token"
        tokenProvider.refreshShouldFail = true

        let client = APIClient(baseURL: testBaseURL, session: makeTestSession(), tokenProvider: tokenProvider)

        await #expect(throws: APIError.sessionExpired) {
            let _: TestItem = try await client.request(
                Endpoint(path: "/v1/test", method: .get)
            )
        }

        #expect(tokenProvider.clearCalled)
        MockURLProtocol.handler = nil
    }

    @Test("404 mapped to notFound")
    func notFound() async throws {
        MockURLProtocol.handler = { _ in
            (Data(), makeResponse(statusCode: 404))
        }

        let client = APIClient(baseURL: testBaseURL, session: makeTestSession())

        await #expect(throws: APIError.notFound) {
            let _: TestItem = try await client.request(
                Endpoint(path: "/v1/test", method: .get, requiresAuth: false)
            )
        }
        MockURLProtocol.handler = nil
    }

    @Test("500 mapped to serverError")
    func serverError() async throws {
        let errorJSON = #"{"message":"Internal server error"}"#
        MockURLProtocol.handler = { _ in
            (Data(errorJSON.utf8), makeResponse(statusCode: 500))
        }

        let client = APIClient(baseURL: testBaseURL, session: makeTestSession())

        await #expect(throws: APIError.serverError(500, "Internal server error")) {
            let _: TestItem = try await client.request(
                Endpoint(path: "/v1/test", method: .get, requiresAuth: false)
            )
        }
        MockURLProtocol.handler = nil
    }

    @Test("400 mapped to badRequest")
    func badRequest() async throws {
        let errorJSON = #"{"message":"Title is required"}"#
        MockURLProtocol.handler = { _ in
            (Data(errorJSON.utf8), makeResponse(statusCode: 400))
        }

        let client = APIClient(baseURL: testBaseURL, session: makeTestSession())

        await #expect(throws: APIError.badRequest("Title is required")) {
            let _: TestItem = try await client.request(
                Endpoint(path: "/v1/test", method: .get, requiresAuth: false)
            )
        }
        MockURLProtocol.handler = nil
    }

    @Test("decoding error mapped correctly")
    func decodingError() async throws {
        let invalidJSON = #"{"wrong_field":"value"}"#
        MockURLProtocol.handler = { _ in
            (Data(invalidJSON.utf8), makeResponse(statusCode: 200))
        }

        let client = APIClient(baseURL: testBaseURL, session: makeTestSession())

        do {
            let _: TestItem = try await client.request(
                Endpoint(path: "/v1/test", method: .get, requiresAuth: false)
            )
            Issue.record("Expected decodingError")
        } catch let error as APIError {
            guard case .decodingError = error else {
                Issue.record("Expected decodingError, got \(error)")
                return
            }
        }
        MockURLProtocol.handler = nil
    }

    @Test("network error when offline")
    func offlineError() async throws {
        MockURLProtocol.handler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let client = APIClient(baseURL: testBaseURL, session: makeTestSession())

        await #expect(throws: APIError.offline) {
            let _: TestItem = try await client.request(
                Endpoint(path: "/v1/test", method: .get, requiresAuth: false)
            )
        }
        MockURLProtocol.handler = nil
    }

    @Test("requestVoid succeeds on 204")
    func requestVoidSuccess() async throws {
        MockURLProtocol.handler = { _ in
            (Data(), makeResponse(statusCode: 204))
        }

        let client = APIClient(baseURL: testBaseURL, session: makeTestSession())
        try await client.requestVoid(
            Endpoint(path: "/v1/test/1", method: .delete, requiresAuth: false)
        )
        MockURLProtocol.handler = nil
    }
}

// MARK: - Endpoint Tests

@Suite("Endpoint")
struct EndpointTests {

    @Test("auth endpoints do not require auth")
    func authEndpointsNoAuth() {
        let login = Endpoint.login(dto: LoginRequestDTO(email: "a@b.com", password: "pass"))
        #expect(login.requiresAuth == false)

        let refresh = Endpoint.refreshToken(dto: RefreshTokenRequestDTO(refreshToken: "tok"))
        #expect(refresh.requiresAuth == false)
    }

    @Test("playbook endpoints use correct paths and methods")
    func playbookEndpoints() {
        let list = Endpoint.getPlaybooks()
        #expect(list.path == "/v1/playbooks")
        #expect(list.method == .get)

        let detail = Endpoint.getPlaybook(id: "abc")
        #expect(detail.path == "/v1/playbooks/abc")

        let delete = Endpoint.deletePlaybook(id: "xyz")
        #expect(delete.method == .delete)
    }

    @Test("task endpoints use correct paths")
    func taskEndpoints() {
        let tasks = Endpoint.getTasks(playbookId: "pb-1")
        #expect(tasks.path == "/v1/playbooks/pb-1/tasks")

        let delete = Endpoint.deleteTask(id: "t-1")
        #expect(delete.path == "/v1/tasks/t-1")
        #expect(delete.method == .delete)
    }
}

// MARK: - DTO Tests

@Suite("DTOs")
struct DTOTests {

    @Test("AuthTokensDTO maps to UserSession (flat format for refresh)")
    func authTokensMapping() {
        let dto = AuthTokensDTO(
            accessToken: "access",
            refreshToken: "refresh",
            userId: "user-1",
            email: "test@example.com"
        )
        let session = dto.toUserSession()
        #expect(session.userId == "user-1")
        #expect(session.email == "test@example.com")
        #expect(session.accessToken == "access")
        #expect(session.refreshToken == "refresh")
    }

    @Test("AuthResponseDTO maps to UserSession (nested format for login/register)")
    func authResponseMapping() {
        let dto = AuthResponseDTO(
            tokens: .init(accessToken: "access", refreshToken: "refresh"),
            user: .init(id: "user-1", email: "test@example.com")
        )
        let session = dto.toUserSession()
        #expect(session.userId == "user-1")
        #expect(session.email == "test@example.com")
        #expect(session.accessToken == "access")
        #expect(session.refreshToken == "refresh")
    }

    @Test("PlaybookDTO Codable roundtrip with snake_case")
    func playbookDTOCodable() throws {
        let json = """
        {
            "id": "pb-1",
            "title": "My Playbook",
            "description": null,
            "phase": "PROOF",
            "archived_at": null,
            "created_at": "2026-01-01T00:00:00Z",
            "updated_at": "2026-01-01T00:00:00Z",
            "tasks": null,
            "sections": null
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let dto = try decoder.decode(PlaybookDTO.self, from: Data(json.utf8))
        #expect(dto.id == "pb-1")
        #expect(dto.title == "My Playbook")
        #expect(dto.phase == "PROOF")
        #expect(dto.archivedAt == nil)
    }

    @Test("TaskDTO Codable roundtrip with snake_case")
    func taskDTOCodable() throws {
        let json = """
        {
            "id": "t-1",
            "playbook_id": "pb-1",
            "title": "Write tests",
            "detail": null,
            "lane": "NOW",
            "estimated_minutes": 90,
            "status": "OPEN",
            "order_index": 0,
            "completed_at": null,
            "created_at": "2026-01-01T00:00:00Z",
            "updated_at": "2026-01-01T00:00:00Z"
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let dto = try decoder.decode(TaskDTO.self, from: Data(json.utf8))
        #expect(dto.id == "t-1")
        #expect(dto.playbookId == "pb-1")
        #expect(dto.lane == "NOW")
        #expect(dto.estimatedMinutes == 90)
    }

    @Test("SectionDTO Codable roundtrip with snake_case")
    func sectionDTOCodable() throws {
        let json = """
        {
            "playbook_id": "pb-1",
            "section_type": "VISION",
            "content": "Build something great",
            "updated_at": "2026-01-01T00:00:00Z"
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let dto = try decoder.decode(SectionDTO.self, from: Data(json.utf8))
        #expect(dto.playbookId == "pb-1")
        #expect(dto.sectionType == "VISION")
        #expect(dto.content == "Build something great")
    }

    @Test("WeeklyCycleDTO Codable roundtrip with snake_case")
    func weeklyCycleDTOCodable() throws {
        let json = """
        {
            "id": "wc-1",
            "playbook_id": "pb-1",
            "week_start_date": "2026-01-06T00:00:00Z",
            "completed_count": 3,
            "total_count": 5,
            "created_at": "2026-01-01T00:00:00Z",
            "updated_at": "2026-01-06T00:00:00Z"
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let dto = try decoder.decode(WeeklyCycleDTO.self, from: Data(json.utf8))
        #expect(dto.id == "wc-1")
        #expect(dto.completedCount == 3)
        #expect(dto.totalCount == 5)
    }
}
