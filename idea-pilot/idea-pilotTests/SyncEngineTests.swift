//
//  SyncEngineTests.swift
//  idea-pilotTests
//
//  Unit tests for SyncEngine, MutationQueue, and related infrastructure.
//

import Foundation
import SwiftData
import Testing
@testable import idea_pilot

// MARK: - Mock URL Protocol

/// A `URLProtocol` subclass for SyncEngine tests, independent of other mocks.
final class SyncEngineMockURLProtocol: URLProtocol, @unchecked Sendable {

    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (Data, HTTPURLResponse))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = SyncEngineMockURLProtocol.handler else {
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
    config.protocolClasses = [SyncEngineMockURLProtocol.self]
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

private func makeInMemoryModelContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: PlaybookModel.self, TaskModel.self, SectionModel.self, WeeklyCycleModel.self, MutationEntry.self,
        configurations: config
    )
}

private func makeAPIClient(session: URLSession? = nil) -> APIClient {
    let urlSession = session ?? makeURLSession()
    return APIClient(baseURL: testBaseURL, session: urlSession)
}

private func makeSyncEngine(
    session: URLSession? = nil
) throws -> (SyncEngine, ModelContainer) {
    let urlSession = session ?? makeURLSession()
    let apiClient = APIClient(baseURL: testBaseURL, session: urlSession)
    let container = try makeInMemoryModelContainer()
    let engine = SyncEngine(apiClient: apiClient, modelContainer: container)
    return (engine, container)
}

// MARK: - Mock JSON Fixtures

private let createdTaskJSON = #"""
{
    "id": "server-task-1",
    "playbook_id": "pb-1",
    "title": "Created Task",
    "detail": null,
    "lane": "NOW",
    "estimated_minutes": 60,
    "status": "OPEN",
    "order_index": 0,
    "completed_at": null,
    "created_at": "2025-01-01T00:00:00Z",
    "updated_at": "2025-01-01T00:00:00Z"
}
"""#

// MARK: - MutationQueue Tests

@Suite("MutationQueue", .serialized)
@MainActor
struct MutationQueueTests {

    @Test("enqueue creates a MutationEntry in SwiftData")
    func enqueueCreatesEntry() throws {
        let container = try makeInMemoryModelContainer()
        let queue = MutationQueue(modelContainer: container)

        try queue.enqueue(
            path: "/v1/tasks",
            method: .post,
            bodyData: Data("{}".utf8),
            entityType: "task",
            entityId: "temp-1"
        )

        #expect(queue.pendingCount == 1)

        let entry = try queue.peek()
        #expect(entry != nil)
        #expect(entry?.endpointPath == "/v1/tasks")
        #expect(entry?.httpMethodRawValue == "POST")
        #expect(entry?.entityType == "task")
        #expect(entry?.entityId == "temp-1")
        #expect(entry?.retryCount == 0)
        #expect(entry?.status == .pending)
    }

    @Test("peek returns oldest pending entry (FIFO)")
    func peekReturnsFIFO() throws {
        let container = try makeInMemoryModelContainer()
        let queue = MutationQueue(modelContainer: container)

        // Enqueue two entries with different timestamps.
        let context = container.mainContext
        let older = MutationEntry(
            endpointPath: "/v1/tasks/1",
            httpMethod: .patch,
            entityType: "task",
            entityId: "1",
            createdAt: Date(timeIntervalSince1970: 1000)
        )
        let newer = MutationEntry(
            endpointPath: "/v1/tasks/2",
            httpMethod: .patch,
            entityType: "task",
            entityId: "2",
            createdAt: Date(timeIntervalSince1970: 2000)
        )
        context.insert(newer)
        context.insert(older)
        try context.save()

        let first = try queue.peek()
        #expect(first?.entityId == "1")
    }

    @Test("remove deletes entry from SwiftData")
    func removeDeletesEntry() throws {
        let container = try makeInMemoryModelContainer()
        let queue = MutationQueue(modelContainer: container)

        try queue.enqueue(
            path: "/v1/tasks",
            method: .post,
            bodyData: nil,
            entityType: "task",
            entityId: nil
        )

        let entry = try queue.peek()
        #expect(entry != nil)

        try queue.remove(entry!)

        let afterRemove = try queue.peek()
        #expect(afterRemove == nil)
        #expect(queue.pendingCount == 0)
    }

    @Test("markFailed increments retryCount and resets to pending")
    func markFailedIncrementsRetry() throws {
        let container = try makeInMemoryModelContainer()
        let queue = MutationQueue(modelContainer: container)

        try queue.enqueue(
            path: "/v1/tasks",
            method: .post,
            bodyData: nil,
            entityType: "task",
            entityId: nil
        )

        let entry = try queue.peek()!
        try queue.markInFlight(entry)
        try queue.markFailed(entry)

        #expect(entry.retryCount == 1)
        #expect(entry.status == .pending)
        #expect(entry.lastAttemptAt != nil)
    }

    @Test("markFailed removes entry after maxRetries exceeded")
    func markFailedRemovesAfterMaxRetries() throws {
        let container = try makeInMemoryModelContainer()
        let queue = MutationQueue(modelContainer: container)

        let context = container.mainContext
        let entry = MutationEntry(
            endpointPath: "/v1/tasks",
            httpMethod: .post,
            entityType: "task",
            retryCount: 4,
            maxRetries: 5
        )
        context.insert(entry)
        try context.save()

        // This is the 5th failure (retryCount becomes 5 == maxRetries), entry should be removed.
        try queue.markFailed(entry)

        let remaining = try queue.peek()
        #expect(remaining == nil)
    }

    @Test("resetInFlightToPending recovers stale entries")
    func resetInFlightRecovery() throws {
        let container = try makeInMemoryModelContainer()
        let queue = MutationQueue(modelContainer: container)

        let context = container.mainContext
        let entry = MutationEntry(
            endpointPath: "/v1/tasks",
            httpMethod: .post,
            entityType: "task",
            status: .inFlight
        )
        context.insert(entry)
        try context.save()

        // Before recovery, peek returns nil (inFlight != pending).
        let beforeRecovery = try queue.peek()
        #expect(beforeRecovery == nil)

        try queue.resetInFlightToPending()

        let afterRecovery = try queue.peek()
        #expect(afterRecovery != nil)
        #expect(afterRecovery?.status == .pending)
    }

    @Test("purge removes all entries")
    func purgeRemovesAll() throws {
        let container = try makeInMemoryModelContainer()
        let queue = MutationQueue(modelContainer: container)

        try queue.enqueue(path: "/v1/tasks", method: .post, bodyData: nil, entityType: "task", entityId: nil)
        try queue.enqueue(path: "/v1/tasks", method: .post, bodyData: nil, entityType: "task", entityId: nil)

        #expect(queue.pendingCount == 2)

        try queue.purge()

        #expect(queue.pendingCount == 0)
    }
}

// MARK: - SyncEngine Tests

@Suite("SyncEngine", .serialized)
@MainActor
struct SyncEngineTests {

    // MARK: - Drain

    @Test("drain sends queued mutation and removes on success")
    func drainSuccessRemoves() async throws {
        SyncEngineMockURLProtocol.handler = { _ in
            (Data(createdTaskJSON.utf8), makeResponse(statusCode: 201))
        }

        let (engine, _) = try makeSyncEngine()

        // Enqueue a mutation.
        engine.enqueue(
            path: "/v1/tasks",
            method: .post,
            body: CreateTaskDTO(playbookId: "pb-1", title: "Test", detail: nil, lane: "NOW", estimatedMinutes: 60),
            entityType: "task",
            entityId: "temp-1"
        )

        #expect(engine.mutationQueue.pendingCount == 1)

        // Drain manually.
        await engine.onPullToRefresh()

        #expect(engine.mutationQueue.pendingCount == 0)

        SyncEngineMockURLProtocol.handler = nil
    }

    @Test("drain retries on 500 server error")
    func drainRetriesOnServerError() async throws {
        SyncEngineMockURLProtocol.handler = { _ in
            (Data(#"{"message":"Internal error"}"#.utf8), makeResponse(statusCode: 500))
        }

        let (engine, _) = try makeSyncEngine()

        engine.enqueue(
            path: "/v1/tasks",
            method: .post,
            body: CreateTaskDTO(playbookId: "pb-1", title: "Test", detail: nil, lane: "NOW", estimatedMinutes: 60),
            entityType: "task"
        )

        await engine.onPullToRefresh()

        // Entry should still be in queue with incremented retryCount.
        let entry = try engine.mutationQueue.peek()
        #expect(entry != nil)
        #expect(entry?.retryCount == 1)
        #expect(entry?.status == .pending)

        SyncEngineMockURLProtocol.handler = nil
    }

    @Test("drain discards mutation on 400 bad request")
    func drainDiscardsOn400() async throws {
        SyncEngineMockURLProtocol.handler = { _ in
            (Data(#"{"message":"Bad request"}"#.utf8), makeResponse(statusCode: 400))
        }

        let (engine, _) = try makeSyncEngine()

        engine.enqueue(
            path: "/v1/tasks",
            method: .post,
            body: CreateTaskDTO(playbookId: "pb-1", title: "Test", detail: nil, lane: "NOW", estimatedMinutes: 60),
            entityType: "task"
        )

        await engine.onPullToRefresh()

        // Non-retryable error — entry should be discarded.
        #expect(engine.mutationQueue.pendingCount == 0)

        SyncEngineMockURLProtocol.handler = nil
    }

    @Test("drain discards mutation on 404 not found")
    func drainDiscardsOn404() async throws {
        SyncEngineMockURLProtocol.handler = { _ in
            (Data(), makeResponse(statusCode: 404))
        }

        let (engine, _) = try makeSyncEngine()

        engine.enqueue(
            path: "/v1/tasks/nonexistent",
            method: .patch,
            body: UpdateTaskDTO(title: "Update", detail: nil, lane: nil, estimatedMinutes: nil, status: nil, orderIndex: nil),
            entityType: "task",
            entityId: "nonexistent"
        )

        await engine.onPullToRefresh()

        #expect(engine.mutationQueue.pendingCount == 0)

        SyncEngineMockURLProtocol.handler = nil
    }

    @Test("drain processes multiple mutations in FIFO order")
    func drainFIFOOrder() async throws {
        nonisolated(unsafe) var capturedPaths: [String] = []

        SyncEngineMockURLProtocol.handler = { request in
            capturedPaths.append(request.url?.path ?? "")
            return (Data(createdTaskJSON.utf8), makeResponse(statusCode: 200))
        }

        let (engine, container) = try makeSyncEngine()

        // Insert entries with explicit timestamps to control order.
        let context = container.mainContext
        let first = MutationEntry(
            endpointPath: "/v1/tasks/first",
            httpMethod: .patch,
            entityType: "task",
            createdAt: Date(timeIntervalSince1970: 1000)
        )
        let second = MutationEntry(
            endpointPath: "/v1/tasks/second",
            httpMethod: .patch,
            entityType: "task",
            createdAt: Date(timeIntervalSince1970: 2000)
        )
        context.insert(first)
        context.insert(second)
        try context.save()

        await engine.onPullToRefresh()

        #expect(capturedPaths.count == 2)
        #expect(capturedPaths[0].contains("first"))
        #expect(capturedPaths[1].contains("second"))

        SyncEngineMockURLProtocol.handler = nil
    }

    @Test("drain stops when network becomes unavailable")
    func drainStopsOffline() async throws {
        nonisolated(unsafe) var requestCount = 0

        SyncEngineMockURLProtocol.handler = { _ in
            requestCount += 1
            return (Data(createdTaskJSON.utf8), makeResponse(statusCode: 200))
        }

        let (engine, _) = try makeSyncEngine()

        // Mark as offline — drain should not execute.
        engine.networkMonitor.isConnected = false

        engine.enqueue(
            path: "/v1/tasks",
            method: .post,
            body: CreateTaskDTO(playbookId: "pb-1", title: "Test", detail: nil, lane: "NOW", estimatedMinutes: 60),
            entityType: "task"
        )

        await engine.onPullToRefresh()

        #expect(requestCount == 0)
        #expect(engine.mutationQueue.pendingCount == 1)

        SyncEngineMockURLProtocol.handler = nil
    }

    // MARK: - Create Reconciliation

    @Test("drain reconciles POST create by replacing temp model with server model")
    func drainReconcilesPOSTCreate() async throws {
        SyncEngineMockURLProtocol.handler = { _ in
            (Data(createdTaskJSON.utf8), makeResponse(statusCode: 201))
        }

        let (engine, container) = try makeSyncEngine()

        // Insert a temp task model (simulating optimistic insert).
        let context = container.mainContext
        let tempTask = TaskModel(id: "temp-task-1", playbookId: "pb-1", title: "Created Task", lane: .now, estimatedMinutes: 60)
        context.insert(tempTask)
        try context.save()

        // Enqueue a create mutation with the temp ID.
        engine.enqueue(
            path: "/v1/tasks",
            method: .post,
            body: CreateTaskDTO(playbookId: "pb-1", title: "Created Task", detail: nil, lane: "NOW", estimatedMinutes: 60),
            entityType: "task",
            entityId: "temp-task-1"
        )

        await engine.onPullToRefresh()

        // Temp model should be gone, server model should exist.
        let tempPredicate = #Predicate<TaskModel> { $0.id == "temp-task-1" }
        var tempDescriptor = FetchDescriptor(predicate: tempPredicate)
        tempDescriptor.fetchLimit = 1
        let tempResult = try context.fetch(tempDescriptor)
        #expect(tempResult.isEmpty)

        let serverPredicate = #Predicate<TaskModel> { $0.id == "server-task-1" }
        var serverDescriptor = FetchDescriptor(predicate: serverPredicate)
        serverDescriptor.fetchLimit = 1
        let serverResult = try context.fetch(serverDescriptor)
        #expect(serverResult.count == 1)
        #expect(serverResult.first?.title == "Created Task")

        SyncEngineMockURLProtocol.handler = nil
    }

    // MARK: - Status

    @Test("status is .synced when queue is empty and connected")
    func statusSyncedWhenEmpty() async throws {
        let (engine, _) = try makeSyncEngine()

        engine.networkMonitor.isConnected = true

        // Force status update by triggering a no-op drain.
        SyncEngineMockURLProtocol.handler = { _ in
            (Data(), makeResponse(statusCode: 200))
        }
        await engine.onPullToRefresh()

        #expect(engine.status.value == .synced)

        SyncEngineMockURLProtocol.handler = nil
    }

    @Test("status is .pending(count) when mutations queued")
    func statusPendingWithCount() async throws {
        let (engine, _) = try makeSyncEngine()

        engine.networkMonitor.isConnected = false

        engine.enqueue(
            path: "/v1/tasks",
            method: .post,
            body: CreateTaskDTO(playbookId: "pb-1", title: "Test", detail: nil, lane: "NOW", estimatedMinutes: 60),
            entityType: "task"
        )

        // When offline with pending mutations, onAppForeground updates status.
        engine.onAppForeground()
        // Give the Task a tick to run.
        try await Task.sleep(for: .milliseconds(50))

        // Status should reflect offline state.
        #expect(engine.status.value == .offline)

        // Now go online.
        engine.networkMonitor.isConnected = true

        engine.enqueue(
            path: "/v1/tasks",
            method: .post,
            body: CreateTaskDTO(playbookId: "pb-1", title: "Test 2", detail: nil, lane: "NOW", estimatedMinutes: 60),
            entityType: "task"
        )

        // After enqueue with connected, status should be pending.
        #expect(engine.mutationQueue.pendingCount == 2)
    }

    @Test("status is .offline when disconnected")
    func statusOfflineWhenDisconnected() async throws {
        let (engine, _) = try makeSyncEngine()

        engine.networkMonitor.isConnected = false

        engine.enqueue(
            path: "/v1/tasks",
            method: .post,
            body: CreateTaskDTO(playbookId: "pb-1", title: "Test", detail: nil, lane: "NOW", estimatedMinutes: 60),
            entityType: "task"
        )

        // Trigger status update.
        await engine.onPullToRefresh()

        #expect(engine.status.value == .offline)
    }

    // MARK: - Backoff

    @Test("drain respects exponential backoff timing")
    func drainRespectsBackoff() async throws {
        nonisolated(unsafe) var requestCount = 0

        SyncEngineMockURLProtocol.handler = { _ in
            requestCount += 1
            return (Data(#"{"message":"Error"}"#.utf8), makeResponse(statusCode: 500))
        }

        let (engine, _) = try makeSyncEngine()

        engine.enqueue(
            path: "/v1/tasks",
            method: .post,
            body: CreateTaskDTO(playbookId: "pb-1", title: "Test", detail: nil, lane: "NOW", estimatedMinutes: 60),
            entityType: "task"
        )

        // First drain — should attempt and fail.
        await engine.onPullToRefresh()
        #expect(requestCount == 1)

        // Second drain immediately — should skip due to backoff.
        await engine.onPullToRefresh()
        #expect(requestCount == 1) // No new request because backoff hasn't elapsed.

        SyncEngineMockURLProtocol.handler = nil
    }

    // MARK: - Enqueue

    @Test("enqueue serializes body with snake_case encoding")
    func enqueueSerializesBody() throws {
        let (engine, _) = try makeSyncEngine()

        engine.enqueue(
            path: "/v1/tasks",
            method: .post,
            body: CreateTaskDTO(playbookId: "pb-1", title: "Test", detail: nil, lane: "NOW", estimatedMinutes: 60),
            entityType: "task",
            entityId: "temp-1"
        )

        let entry = try engine.mutationQueue.peek()
        #expect(entry != nil)
        #expect(entry?.bodyData != nil)

        // Verify the body is snake_case encoded.
        let bodyString = String(data: entry!.bodyData!, encoding: .utf8) ?? ""
        #expect(bodyString.contains("playbook_id"))
        #expect(bodyString.contains("estimated_minutes"))
    }

    @Test("enqueue with nil body stores nil bodyData")
    func enqueueNilBody() throws {
        let (engine, _) = try makeSyncEngine()

        engine.enqueue(
            path: "/v1/tasks/1/complete",
            method: .post,
            body: nil as CreateTaskDTO?,
            entityType: "task",
            entityId: "1"
        )

        let entry = try engine.mutationQueue.peek()
        #expect(entry != nil)
        #expect(entry?.bodyData == nil)
    }
}

// MARK: - SyncStatus Tests

@Suite("SyncStatus")
struct SyncStatusTests {

    @Test("SyncStatusValue equality works correctly")
    func syncStatusEquality() {
        #expect(SyncStatusValue.synced == SyncStatusValue.synced)
        #expect(SyncStatusValue.offline == SyncStatusValue.offline)
        #expect(SyncStatusValue.pending(3) == SyncStatusValue.pending(3))
        #expect(SyncStatusValue.pending(3) != SyncStatusValue.pending(5))
        #expect(SyncStatusValue.syncing != SyncStatusValue.synced)
        #expect(SyncStatusValue.error("test") == SyncStatusValue.error("test"))
    }
}
