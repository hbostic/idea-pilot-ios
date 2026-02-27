//
//  WeeklyPlanServiceTests.swift
//  idea-pilotTests
//
//  Unit tests for WeeklyPlanService with mock networking and in-memory SwiftData.
//

import Foundation
import SwiftData
import Testing
@testable import idea_pilot

// MARK: - Mock URL Protocol

/// A `URLProtocol` subclass for WeeklyPlanService tests, independent of other mocks.
final class WeeklyPlanMockURLProtocol: URLProtocol, @unchecked Sendable {

    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (Data, HTTPURLResponse))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = WeeklyPlanMockURLProtocol.handler else {
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
    config.protocolClasses = [WeeklyPlanMockURLProtocol.self]
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

private nonisolated func makeWeeklyPlanService(
    session: URLSession? = nil
) throws -> (WeeklyPlanService, ModelContainer) {
    let urlSession = session ?? makeURLSession()
    let apiClient = APIClient(baseURL: testBaseURL, session: urlSession)
    let container = try makeInMemoryModelContainer()
    let service = WeeklyPlanService(apiClient: apiClient, modelContainer: container)
    return (service, container)
}

// MARK: - Mock JSON Fixtures

private let weeklyStatusJSON = #"""
{
    "id": "wc-1",
    "playbook_id": "pb-1",
    "week_start_date": "2025-06-02T00:00:00Z",
    "completed_count": 3,
    "total_count": 5,
    "created_at": "2025-06-02T00:00:00Z",
    "updated_at": "2025-06-04T00:00:00Z"
}
"""#

private let weeklyPlanResponseJSON = #"""
{
    "id": "wc-2",
    "playbook_id": "pb-1",
    "week_start_date": "2025-06-09T00:00:00Z",
    "completed_count": 0,
    "total_count": 3,
    "created_at": "2025-06-09T00:00:00Z",
    "updated_at": "2025-06-09T00:00:00Z"
}
"""#

private let weeklyCyclesArrayJSON = #"""
[
    {
        "id": "wc-1",
        "playbook_id": "pb-1",
        "week_start_date": "2025-06-02T00:00:00Z",
        "completed_count": 3,
        "total_count": 5,
        "created_at": "2025-06-02T00:00:00Z",
        "updated_at": "2025-06-04T00:00:00Z"
    },
    {
        "id": "wc-2",
        "playbook_id": "pb-1",
        "week_start_date": "2025-06-09T00:00:00Z",
        "completed_count": 0,
        "total_count": 3,
        "created_at": "2025-06-09T00:00:00Z",
        "updated_at": "2025-06-09T00:00:00Z"
    }
]
"""#

// MARK: - Tests

@Suite("WeeklyPlanService", .serialized)
struct WeeklyPlanServiceTests {

    // MARK: - Get Weekly Status

    @Test("getWeeklyStatus decodes and upserts into SwiftData")
    func getWeeklyStatusSuccess() async throws {
        WeeklyPlanMockURLProtocol.handler = { _ in
            (Data(weeklyStatusJSON.utf8), makeResponse(statusCode: 200))
        }
        let (service, container) = try makeWeeklyPlanService()

        let model = try await service.getWeeklyStatus(playbookId: "pb-1")

        #expect(model.id == "wc-1")
        #expect(model.completedCount == 3)
        #expect(model.totalCount == 5)
        #expect(model.playbookId == "pb-1")

        // Verify persisted in SwiftData.
        let context = await container.mainContext
        let descriptor = FetchDescriptor<WeeklyCycleModel>()
        let persisted = try await context.fetch(descriptor)
        #expect(persisted.count == 1)
        #expect(persisted.first?.completedCount == 3)

        WeeklyPlanMockURLProtocol.handler = nil
    }

    @Test("getWeeklyStatus server error throws WeeklyPlanError.serverError")
    func getWeeklyStatusServerError() async throws {
        let errorJSON = #"{"message":"Internal server error"}"#
        WeeklyPlanMockURLProtocol.handler = { _ in
            (Data(errorJSON.utf8), makeResponse(statusCode: 500))
        }
        let (service, _) = try makeWeeklyPlanService()

        do {
            _ = try await service.getWeeklyStatus(playbookId: "pb-1")
            Issue.record("Expected WeeklyPlanError.serverError")
        } catch let error as WeeklyPlanError {
            guard case .serverError = error else {
                Issue.record("Expected serverError, got \(error)")
                return
            }
        }

        WeeklyPlanMockURLProtocol.handler = nil
    }

    // MARK: - Create Weekly Plan

    @Test("createWeeklyPlan sends POST with task IDs and upserts response")
    func createWeeklyPlanSuccess() async throws {
        nonisolated(unsafe) var capturedMethod: String?
        nonisolated(unsafe) var capturedPath: String?
        nonisolated(unsafe) var capturedBody: Data?

        WeeklyPlanMockURLProtocol.handler = { request in
            capturedMethod = request.httpMethod
            capturedPath = request.url?.path
            capturedBody = request.httpBodyStreamData ?? request.httpBody
            return (Data(weeklyPlanResponseJSON.utf8), makeResponse(statusCode: 200))
        }

        let (service, container) = try makeWeeklyPlanService()

        let model = try await service.createWeeklyPlan(
            playbookId: "pb-1",
            taskIds: ["t-1", "t-2", "t-3"]
        )

        #expect(capturedMethod == "POST")
        #expect(capturedPath?.contains("/v1/playbooks/pb-1/weekly/plan") == true)
        #expect(model.totalCount == 3)
        #expect(model.completedCount == 0)

        // Verify persisted in SwiftData.
        let context = await container.mainContext
        let descriptor = FetchDescriptor<WeeklyCycleModel>()
        let persisted = try await context.fetch(descriptor)
        #expect(persisted.count == 1)

        WeeklyPlanMockURLProtocol.handler = nil
    }

    @Test("createWeeklyPlan bad request throws WeeklyPlanError.serverError")
    func createWeeklyPlanBadRequest() async throws {
        let errorJSON = #"{"message":"Task selection required"}"#
        WeeklyPlanMockURLProtocol.handler = { _ in
            (Data(errorJSON.utf8), makeResponse(statusCode: 400))
        }
        let (service, _) = try makeWeeklyPlanService()

        do {
            _ = try await service.createWeeklyPlan(playbookId: "pb-1", taskIds: [])
            Issue.record("Expected WeeklyPlanError.serverError")
        } catch let error as WeeklyPlanError {
            guard case .serverError = error else {
                Issue.record("Expected serverError, got \(error)")
                return
            }
        }

        WeeklyPlanMockURLProtocol.handler = nil
    }

    // MARK: - Fetch Weekly Cycles

    @Test("fetchWeeklyCycles decodes array and upserts into SwiftData")
    func fetchWeeklyCyclesSuccess() async throws {
        WeeklyPlanMockURLProtocol.handler = { _ in
            (Data(weeklyCyclesArrayJSON.utf8), makeResponse(statusCode: 200))
        }
        let (service, container) = try makeWeeklyPlanService()

        let models = try await service.fetchWeeklyCycles(playbookId: "pb-1")

        #expect(models.count == 2)
        #expect(models.contains { $0.id == "wc-1" && $0.completedCount == 3 })
        #expect(models.contains { $0.id == "wc-2" && $0.totalCount == 3 })

        // Verify persisted in SwiftData.
        let context = await container.mainContext
        let descriptor = FetchDescriptor<WeeklyCycleModel>()
        let persisted = try await context.fetch(descriptor)
        #expect(persisted.count == 2)

        WeeklyPlanMockURLProtocol.handler = nil
    }

    @Test("fetchWeeklyCycles falls back to SwiftData cache when offline")
    func fetchWeeklyCyclesOfflineFallback() async throws {
        let (service, container) = try makeWeeklyPlanService()

        // Pre-populate cache.
        let context = await container.mainContext
        let cached = WeeklyCycleModel(id: "wc-cached", playbookId: "pb-1", weekStartDate: .now, completedCount: 2, totalCount: 4)
        await context.insert(cached)
        try await context.save()

        // Simulate offline.
        WeeklyPlanMockURLProtocol.handler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let models = try await service.fetchWeeklyCycles(playbookId: "pb-1")
        #expect(models.count == 1)
        #expect(models.first?.id == "wc-cached")
        #expect(models.first?.completedCount == 2)

        WeeklyPlanMockURLProtocol.handler = nil
    }

    @Test("fetchWeeklyCycles server error throws WeeklyPlanError.serverError")
    func fetchWeeklyCyclesServerError() async throws {
        let errorJSON = #"{"message":"Internal server error"}"#
        WeeklyPlanMockURLProtocol.handler = { _ in
            (Data(errorJSON.utf8), makeResponse(statusCode: 500))
        }
        let (service, _) = try makeWeeklyPlanService()

        do {
            _ = try await service.fetchWeeklyCycles(playbookId: "pb-1")
            Issue.record("Expected WeeklyPlanError.serverError")
        } catch let error as WeeklyPlanError {
            guard case .serverError = error else {
                Issue.record("Expected serverError, got \(error)")
                return
            }
        }

        WeeklyPlanMockURLProtocol.handler = nil
    }
}

// MARK: - URLRequest httpBodyStreamData Helper

private extension URLRequest {
    /// Reads the httpBodyStream into Data (used when httpBody is nil but stream exists).
    var httpBodyStreamData: Data? {
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let bytesRead = stream.read(buffer, maxLength: bufferSize)
            guard bytesRead > 0 else { break }
            data.append(buffer, count: bytesRead)
        }
        return data.isEmpty ? nil : data
    }
}
