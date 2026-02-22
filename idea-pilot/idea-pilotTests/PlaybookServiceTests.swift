//
//  PlaybookServiceTests.swift
//  idea-pilotTests
//
//  Unit tests for PlaybookService with mock networking and in-memory SwiftData.
//

import Foundation
import SwiftData
import Testing
@testable import idea_pilot

// MARK: - Mock URL Protocol (independent from other test suites)

/// A `URLProtocol` subclass for PlaybookService tests, independent of other mocks.
final class PlaybookServiceMockURLProtocol: URLProtocol, @unchecked Sendable {

    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (Data, HTTPURLResponse))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = PlaybookServiceMockURLProtocol.handler else {
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
    config.protocolClasses = [PlaybookServiceMockURLProtocol.self]
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

private nonisolated func makeInMemoryModelContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: PlaybookModel.self, TaskModel.self, SectionModel.self, WeeklyCycleModel.self,
        configurations: config
    )
}

private nonisolated func makePlaybookService(
    session: URLSession? = nil
) throws -> (PlaybookService, ModelContainer) {
    let urlSession = session ?? makeURLSession()
    let apiClient = APIClient(baseURL: testBaseURL, session: urlSession)
    let container = try makeInMemoryModelContainer()
    let service = PlaybookService(apiClient: apiClient, modelContainer: container)
    return (service, container)
}

// MARK: - Mock JSON Fixtures

private let singlePlaybookJSON = #"""
{
    "id": "pb-1",
    "title": "Test Playbook",
    "description": "A test playbook",
    "phase": "PROOF",
    "is_archived": false,
    "created_at": "2025-01-01T00:00:00Z",
    "updated_at": "2025-01-02T00:00:00Z"
}
"""#

private let playbooksArrayJSON = #"""
[
    {
        "id": "pb-1",
        "title": "Playbook One",
        "description": "First playbook",
        "phase": "PROOF",
        "is_archived": false,
        "created_at": "2025-01-01T00:00:00Z",
        "updated_at": "2025-01-02T00:00:00Z"
    },
    {
        "id": "pb-2",
        "title": "Playbook Two",
        "description": null,
        "phase": "STRUCTURE",
        "is_archived": false,
        "created_at": "2025-01-03T00:00:00Z",
        "updated_at": "2025-01-04T00:00:00Z"
    }
]
"""#

private let updatedPlaybookJSON = #"""
[
    {
        "id": "pb-1",
        "title": "Updated Title",
        "description": "Updated description",
        "phase": "STRUCTURE",
        "is_archived": false,
        "created_at": "2025-01-01T00:00:00Z",
        "updated_at": "2025-01-10T00:00:00Z"
    }
]
"""#

// MARK: - PlaybookService Tests

@Suite("PlaybookService", .serialized)
struct PlaybookServiceTests {

    // MARK: - Fetch

    @Test("fetchPlaybooks decodes array and upserts into SwiftData")
    func fetchPlaybooksSuccess() async throws {
        PlaybookServiceMockURLProtocol.handler = { _ in
            (Data(playbooksArrayJSON.utf8), makeResponse(statusCode: 200))
        }

        let (service, container) = try makePlaybookService()
        let models = try await service.fetchPlaybooks(updatedSince: nil)

        #expect(models.count == 2)
        #expect(models.contains { $0.id == "pb-1" && $0.title == "Playbook One" })
        #expect(models.contains { $0.id == "pb-2" && $0.title == "Playbook Two" })

        // Verify SwiftData persistence.
        let context = await container.mainContext
        let descriptor = FetchDescriptor<PlaybookModel>()
        let persisted = try await context.fetch(descriptor)
        #expect(persisted.count == 2)

        PlaybookServiceMockURLProtocol.handler = nil
    }

    @Test("fetchPlaybooks upserts existing models instead of duplicating")
    func fetchPlaybooksUpserts() async throws {
        let (service, container) = try makePlaybookService()

        // First fetch — inserts.
        PlaybookServiceMockURLProtocol.handler = { _ in
            (Data(playbooksArrayJSON.utf8), makeResponse(statusCode: 200))
        }
        _ = try await service.fetchPlaybooks(updatedSince: nil)

        // Second fetch — same IDs, updated data.
        PlaybookServiceMockURLProtocol.handler = { _ in
            (Data(updatedPlaybookJSON.utf8), makeResponse(statusCode: 200))
        }
        let models = try await service.fetchPlaybooks(updatedSince: nil)

        #expect(models.count == 1)
        #expect(models.first?.title == "Updated Title")
        #expect(models.first?.phase == .structure)

        // Verify no duplicates — should still have 2 total (pb-1 updated + pb-2 unchanged).
        let context = await container.mainContext
        let descriptor = FetchDescriptor<PlaybookModel>()
        let persisted = try await context.fetch(descriptor)
        #expect(persisted.count == 2)

        PlaybookServiceMockURLProtocol.handler = nil
    }

    @Test("fetchPlaybooks falls back to SwiftData cache when offline")
    func fetchPlaybooksOfflineFallback() async throws {
        let (service, container) = try makePlaybookService()

        // Seed SwiftData with a cached playbook.
        let context = await container.mainContext
        let cached = PlaybookModel(id: "pb-cached", title: "Cached Playbook")
        await context.insert(cached)
        try await context.save()

        // Simulate offline.
        PlaybookServiceMockURLProtocol.handler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let models = try await service.fetchPlaybooks(updatedSince: nil)

        #expect(models.count == 1)
        #expect(models.first?.title == "Cached Playbook")

        PlaybookServiceMockURLProtocol.handler = nil
    }

    @Test("fetchPlaybooks sends updated_since query parameter")
    func fetchPlaybooksWithUpdatedSince() async throws {
        nonisolated(unsafe) var capturedURL: URL?

        PlaybookServiceMockURLProtocol.handler = { request in
            capturedURL = request.url
            return (Data("[]".utf8), makeResponse(statusCode: 200))
        }

        let (service, _) = try makePlaybookService()
        let date = ISO8601DateFormatter().date(from: "2025-06-01T00:00:00Z")!
        _ = try await service.fetchPlaybooks(updatedSince: date)

        #expect(capturedURL?.absoluteString.contains("updated_since=") == true)

        PlaybookServiceMockURLProtocol.handler = nil
    }

    @Test("fetchPlaybooks server error throws PlaybookError.serverError")
    func fetchPlaybooksServerError() async throws {
        let errorJSON = #"{"message":"Internal server error"}"#
        PlaybookServiceMockURLProtocol.handler = { _ in
            (Data(errorJSON.utf8), makeResponse(statusCode: 500))
        }

        let (service, _) = try makePlaybookService()

        do {
            _ = try await service.fetchPlaybooks(updatedSince: nil)
            Issue.record("Expected PlaybookError.serverError")
        } catch let error as PlaybookError {
            guard case .serverError = error else {
                Issue.record("Expected serverError, got \(error)")
                return
            }
        }

        PlaybookServiceMockURLProtocol.handler = nil
    }

    // MARK: - Create

    @Test("createPlaybook creates via API and inserts into SwiftData")
    func createPlaybookSuccess() async throws {
        PlaybookServiceMockURLProtocol.handler = { _ in
            (Data(singlePlaybookJSON.utf8), makeResponse(statusCode: 201))
        }

        let (service, container) = try makePlaybookService()
        let model = try await service.createPlaybook(title: "Test Playbook", description: "A test playbook")

        #expect(model.id == "pb-1")
        #expect(model.title == "Test Playbook")
        #expect(model.phase == .proof)

        // Verify SwiftData persistence.
        let context = await container.mainContext
        let descriptor = FetchDescriptor<PlaybookModel>()
        let persisted = try await context.fetch(descriptor)
        #expect(persisted.count == 1)

        PlaybookServiceMockURLProtocol.handler = nil
    }

    @Test("createPlaybook network error throws PlaybookError.networkError")
    func createPlaybookNetworkError() async throws {
        PlaybookServiceMockURLProtocol.handler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let (service, _) = try makePlaybookService()

        do {
            _ = try await service.createPlaybook(title: "Test", description: nil)
            Issue.record("Expected PlaybookError.networkError")
        } catch let error as PlaybookError {
            guard case .networkError = error else {
                Issue.record("Expected networkError, got \(error)")
                return
            }
        }

        PlaybookServiceMockURLProtocol.handler = nil
    }

    // MARK: - Archive

    @Test("archivePlaybook calls endpoint and updates SwiftData")
    func archivePlaybookSuccess() async throws {
        let (service, container) = try makePlaybookService()

        // Seed SwiftData with a playbook.
        let context = await container.mainContext
        let playbook = PlaybookModel(id: "pb-1", title: "To Archive")
        await context.insert(playbook)
        try await context.save()

        nonisolated(unsafe) var capturedPath: String?
        nonisolated(unsafe) var capturedMethod: String?

        PlaybookServiceMockURLProtocol.handler = { request in
            capturedPath = request.url?.path
            capturedMethod = request.httpMethod
            return (Data(), makeResponse(statusCode: 200))
        }

        try await service.archivePlaybook(id: "pb-1")

        #expect(capturedPath?.contains("/v1/playbooks/pb-1/archive") == true)
        #expect(capturedMethod == "POST")

        // Verify SwiftData update.
        let predicate = #Predicate<PlaybookModel> { $0.id == "pb-1" }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        let updated = try await context.fetch(descriptor).first
        #expect(updated?.isArchived == true)

        PlaybookServiceMockURLProtocol.handler = nil
    }

    @Test("archivePlaybook 404 throws PlaybookError.notFound")
    func archivePlaybookNotFound() async throws {
        PlaybookServiceMockURLProtocol.handler = { _ in
            (Data(), makeResponse(statusCode: 404))
        }

        let (service, _) = try makePlaybookService()

        do {
            try await service.archivePlaybook(id: "nonexistent")
            Issue.record("Expected PlaybookError.notFound")
        } catch let error as PlaybookError {
            #expect(error == .notFound)
        }

        PlaybookServiceMockURLProtocol.handler = nil
    }
}
