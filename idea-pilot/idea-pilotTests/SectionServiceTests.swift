//
//  SectionServiceTests.swift
//  idea-pilotTests
//
//  Unit tests for SectionService with mock networking and in-memory SwiftData.
//

import Foundation
import SwiftData
import Testing
@testable import idea_pilot

// MARK: - Mock URL Protocol (independent from other test suites)

/// A `URLProtocol` subclass for SectionService tests, independent of other mocks.
final class SectionServiceMockURLProtocol: URLProtocol, @unchecked Sendable {

    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (Data, HTTPURLResponse))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = SectionServiceMockURLProtocol.handler else {
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
    config.protocolClasses = [SectionServiceMockURLProtocol.self]
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

private nonisolated func makeSectionService(
    session: URLSession? = nil
) throws -> (SectionService, ModelContainer) {
    let urlSession = session ?? makeURLSession()
    let apiClient = APIClient(baseURL: testBaseURL, session: urlSession)
    let container = try makeInMemoryModelContainer()
    let service = SectionService(apiClient: apiClient, modelContainer: container)
    return (service, container)
}

// MARK: - Mock JSON Fixtures

private let sectionsArrayJSON = #"""
[
    {
        "playbook_id": "pb-1",
        "section_type": "VISION",
        "content": "Our vision is...",
        "updated_at": "2025-01-01T00:00:00Z"
    },
    {
        "playbook_id": "pb-1",
        "section_type": "SYSTEM",
        "content": "The system works by...",
        "updated_at": "2025-01-02T00:00:00Z"
    },
    {
        "playbook_id": "pb-1",
        "section_type": "BUILD",
        "content": "",
        "updated_at": "2025-01-03T00:00:00Z"
    },
    {
        "playbook_id": "pb-1",
        "section_type": "BUSINESS_MODEL",
        "content": "Revenue streams include...",
        "updated_at": "2025-01-04T00:00:00Z"
    }
]
"""#

private let updatedSectionJSON = #"""
{
    "playbook_id": "pb-1",
    "section_type": "VISION",
    "content": "Updated vision content",
    "updated_at": "2025-01-10T00:00:00Z"
}
"""#

// MARK: - Tests

@Suite("SectionService", .serialized)
struct SectionServiceTests {

    // MARK: - Fetch

    @Test("fetchSections decodes array and upserts into SwiftData")
    func fetchSectionsSuccess() async throws {
        SectionServiceMockURLProtocol.handler = { _ in
            (Data(sectionsArrayJSON.utf8), makeResponse(statusCode: 200))
        }
        let (service, container) = try makeSectionService()

        let models = try await service.fetchSections(playbookId: "pb-1", updatedSince: nil)

        #expect(models.count == 4)
        #expect(models.contains { $0.sectionType == .vision && $0.content == "Our vision is..." })
        #expect(models.contains { $0.sectionType == .system })
        #expect(models.contains { $0.sectionType == .build })
        #expect(models.contains { $0.sectionType == .businessModel })

        // Verify persisted in SwiftData.
        let context = await container.mainContext
        let descriptor = FetchDescriptor<SectionModel>()
        let persisted = try await context.fetch(descriptor)
        #expect(persisted.count == 4)

        SectionServiceMockURLProtocol.handler = nil
    }

    @Test("fetchSections upserts existing sections instead of duplicating")
    func fetchSectionsUpserts() async throws {
        let (service, container) = try makeSectionService()

        // First fetch — seed all 4 sections.
        SectionServiceMockURLProtocol.handler = { _ in
            (Data(sectionsArrayJSON.utf8), makeResponse(statusCode: 200))
        }
        _ = try await service.fetchSections(playbookId: "pb-1", updatedSince: nil)

        // Second fetch — only vision with updated content.
        let updatedArrayJSON = #"""
        [
            {
                "playbook_id": "pb-1",
                "section_type": "VISION",
                "content": "New vision",
                "updated_at": "2025-02-01T00:00:00Z"
            }
        ]
        """#
        SectionServiceMockURLProtocol.handler = { _ in
            (Data(updatedArrayJSON.utf8), makeResponse(statusCode: 200))
        }
        let models = try await service.fetchSections(playbookId: "pb-1", updatedSince: nil)

        #expect(models.count == 1)
        #expect(models.first?.content == "New vision")

        // Total should still be 4 (3 from first + 1 upserted).
        let context = await container.mainContext
        let descriptor = FetchDescriptor<SectionModel>()
        let persisted = try await context.fetch(descriptor)
        #expect(persisted.count == 4)

        SectionServiceMockURLProtocol.handler = nil
    }

    @Test("fetchSections falls back to SwiftData cache when offline")
    func fetchSectionsOfflineFallback() async throws {
        let (service, container) = try makeSectionService()

        // Pre-populate cache.
        let context = await container.mainContext
        let cached = SectionModel(playbookId: "pb-1", sectionType: .vision, content: "Cached vision")
        await context.insert(cached)
        try await context.save()

        // Simulate offline.
        SectionServiceMockURLProtocol.handler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let models = try await service.fetchSections(playbookId: "pb-1", updatedSince: nil)
        #expect(models.count == 1)
        #expect(models.first?.content == "Cached vision")

        SectionServiceMockURLProtocol.handler = nil
    }

    @Test("fetchSections server error throws SectionError.serverError")
    func fetchSectionsServerError() async throws {
        let errorJSON = #"{"message":"Internal server error"}"#
        SectionServiceMockURLProtocol.handler = { _ in
            (Data(errorJSON.utf8), makeResponse(statusCode: 500))
        }
        let (service, _) = try makeSectionService()

        do {
            _ = try await service.fetchSections(playbookId: "pb-1", updatedSince: nil)
            Issue.record("Expected SectionError.serverError")
        } catch let error as SectionError {
            guard case .serverError = error else {
                Issue.record("Expected serverError, got \(error)")
                return
            }
        }

        SectionServiceMockURLProtocol.handler = nil
    }

    // MARK: - Update

    @Test("updateSection sends PUT and upserts response into SwiftData")
    func updateSectionSuccess() async throws {
        nonisolated(unsafe) var capturedMethod: String?
        nonisolated(unsafe) var capturedPath: String?

        SectionServiceMockURLProtocol.handler = { request in
            capturedMethod = request.httpMethod
            capturedPath = request.url?.path
            return (Data(updatedSectionJSON.utf8), makeResponse(statusCode: 200))
        }

        let (service, container) = try makeSectionService()

        let model = try await service.updateSection(
            playbookId: "pb-1",
            sectionType: .vision,
            content: "Updated vision content"
        )

        #expect(capturedMethod == "PUT")
        #expect(capturedPath?.contains("/v1/playbooks/pb-1/sections/VISION") == true)
        #expect(model.content == "Updated vision content")
        #expect(model.sectionType == .vision)

        // Verify persisted in SwiftData.
        let context = await container.mainContext
        let descriptor = FetchDescriptor<SectionModel>()
        let persisted = try await context.fetch(descriptor)
        #expect(persisted.count == 1)
        #expect(persisted.first?.content == "Updated vision content")

        SectionServiceMockURLProtocol.handler = nil
    }

    @Test("updateSection 404 throws SectionError.notFound")
    func updateSectionNotFound() async throws {
        SectionServiceMockURLProtocol.handler = { _ in
            (Data(), makeResponse(statusCode: 404))
        }
        let (service, _) = try makeSectionService()

        do {
            _ = try await service.updateSection(playbookId: "pb-1", sectionType: .vision, content: "text")
            Issue.record("Expected SectionError.notFound")
        } catch let error as SectionError {
            #expect(error == .notFound)
        }

        SectionServiceMockURLProtocol.handler = nil
    }

    @Test("updateSection network error throws SectionError.networkError")
    func updateSectionNetworkError() async throws {
        SectionServiceMockURLProtocol.handler = { _ in
            throw URLError(.notConnectedToInternet)
        }
        let (service, _) = try makeSectionService()

        do {
            _ = try await service.updateSection(playbookId: "pb-1", sectionType: .vision, content: "text")
            Issue.record("Expected SectionError.networkError")
        } catch let error as SectionError {
            guard case .networkError = error else {
                Issue.record("Expected networkError, got \(error)")
                return
            }
        }

        SectionServiceMockURLProtocol.handler = nil
    }
}
