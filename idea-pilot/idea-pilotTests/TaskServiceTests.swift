//
//  TaskServiceTests.swift
//  idea-pilotTests
//
//  Unit tests for TaskService with mock networking and in-memory SwiftData.
//

import Foundation
import SwiftData
import Testing
@testable import idea_pilot

// MARK: - Mock URL Protocol (independent from other test suites)

/// A `URLProtocol` subclass for TaskService tests, independent of other mocks.
final class TaskServiceMockURLProtocol: URLProtocol, @unchecked Sendable {

    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (Data, HTTPURLResponse))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = TaskServiceMockURLProtocol.handler else {
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
    config.protocolClasses = [TaskServiceMockURLProtocol.self]
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

private nonisolated func makeTaskService(
    session: URLSession? = nil
) throws -> (TaskService, ModelContainer) {
    let urlSession = session ?? makeURLSession()
    let apiClient = APIClient(baseURL: testBaseURL, session: urlSession)
    let container = try makeInMemoryModelContainer()
    let service = TaskService(apiClient: apiClient, modelContainer: container)
    return (service, container)
}

// MARK: - Mock JSON Fixtures

private let singleTaskJSON = #"""
{
    "id": "task-1",
    "playbook_id": "pb-1",
    "title": "Write tests",
    "detail": "Unit tests for TaskService",
    "lane": "NOW",
    "estimated_minutes": 90,
    "status": "OPEN",
    "order_index": 0,
    "completed_at": null,
    "created_at": "2025-01-01T00:00:00Z",
    "updated_at": "2025-01-02T00:00:00Z"
}
"""#

private let tasksArrayJSON = #"""
[
    {
        "id": "task-1",
        "playbook_id": "pb-1",
        "title": "Task One",
        "detail": null,
        "lane": "NOW",
        "estimated_minutes": 60,
        "status": "OPEN",
        "order_index": 0,
        "completed_at": null,
        "created_at": "2025-01-01T00:00:00Z",
        "updated_at": "2025-01-02T00:00:00Z"
    },
    {
        "id": "task-2",
        "playbook_id": "pb-1",
        "title": "Task Two",
        "detail": "Some detail",
        "lane": "NEXT",
        "estimated_minutes": 120,
        "status": "OPEN",
        "order_index": 1,
        "completed_at": null,
        "created_at": "2025-01-03T00:00:00Z",
        "updated_at": "2025-01-04T00:00:00Z"
    }
]
"""#

private let updatedTasksJSON = #"""
[
    {
        "id": "task-1",
        "playbook_id": "pb-1",
        "title": "Updated Title",
        "detail": "Updated detail",
        "lane": "NEXT",
        "estimated_minutes": 120,
        "status": "OPEN",
        "order_index": 0,
        "completed_at": null,
        "created_at": "2025-01-01T00:00:00Z",
        "updated_at": "2025-01-10T00:00:00Z"
    }
]
"""#

private let completedTaskJSON = #"""
{
    "id": "task-1",
    "playbook_id": "pb-1",
    "title": "Task One",
    "detail": null,
    "lane": "NOW",
    "estimated_minutes": 60,
    "status": "DONE",
    "order_index": 0,
    "completed_at": "2025-01-05T12:00:00Z",
    "created_at": "2025-01-01T00:00:00Z",
    "updated_at": "2025-01-05T12:00:00Z"
}
"""#

private let updatedSingleTaskJSON = #"""
{
    "id": "task-1",
    "playbook_id": "pb-1",
    "title": "Patched Title",
    "detail": "Patched detail",
    "lane": "LATER",
    "estimated_minutes": 45,
    "status": "OPEN",
    "order_index": 0,
    "completed_at": null,
    "created_at": "2025-01-01T00:00:00Z",
    "updated_at": "2025-01-10T00:00:00Z"
}
"""#

// MARK: - TaskService Tests

@Suite("TaskService", .serialized)
struct TaskServiceTests {

    // MARK: - Fetch

    @Test("fetchTasks decodes array and upserts into SwiftData")
    func fetchTasksSuccess() async throws {
        TaskServiceMockURLProtocol.handler = { _ in
            (Data(tasksArrayJSON.utf8), makeResponse(statusCode: 200))
        }

        let (service, container) = try makeTaskService()
        let models = try await service.fetchTasks(playbookId: "pb-1", lane: nil, updatedSince: nil)

        #expect(models.count == 2)
        #expect(models.contains { $0.id == "task-1" && $0.title == "Task One" })
        #expect(models.contains { $0.id == "task-2" && $0.title == "Task Two" })

        // Verify SwiftData persistence.
        let context = await container.mainContext
        let descriptor = FetchDescriptor<TaskModel>()
        let persisted = try await context.fetch(descriptor)
        #expect(persisted.count == 2)

        TaskServiceMockURLProtocol.handler = nil
    }

    @Test("fetchTasks upserts existing models instead of duplicating")
    func fetchTasksUpserts() async throws {
        let (service, container) = try makeTaskService()

        // First fetch — inserts.
        TaskServiceMockURLProtocol.handler = { _ in
            (Data(tasksArrayJSON.utf8), makeResponse(statusCode: 200))
        }
        _ = try await service.fetchTasks(playbookId: "pb-1", lane: nil, updatedSince: nil)

        // Second fetch — same IDs, updated data.
        TaskServiceMockURLProtocol.handler = { _ in
            (Data(updatedTasksJSON.utf8), makeResponse(statusCode: 200))
        }
        let models = try await service.fetchTasks(playbookId: "pb-1", lane: nil, updatedSince: nil)

        #expect(models.count == 1)
        #expect(models.first?.title == "Updated Title")
        #expect(models.first?.lane == .next)

        // Verify no duplicates — should still have 2 total (task-1 updated + task-2 unchanged).
        let context = await container.mainContext
        let descriptor = FetchDescriptor<TaskModel>()
        let persisted = try await context.fetch(descriptor)
        #expect(persisted.count == 2)

        TaskServiceMockURLProtocol.handler = nil
    }

    @Test("fetchTasks falls back to SwiftData cache when offline")
    func fetchTasksOfflineFallback() async throws {
        let (service, container) = try makeTaskService()

        // Seed SwiftData with a cached task.
        let context = await container.mainContext
        let cached = TaskModel(playbookId: "pb-1", title: "Cached Task", lane: .now)
        await context.insert(cached)
        try await context.save()

        // Simulate offline.
        TaskServiceMockURLProtocol.handler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let models = try await service.fetchTasks(playbookId: "pb-1", lane: nil, updatedSince: nil)

        #expect(models.count == 1)
        #expect(models.first?.title == "Cached Task")

        TaskServiceMockURLProtocol.handler = nil
    }

    @Test("fetchTasks sends lane and updated_since query parameters")
    func fetchTasksWithLaneAndUpdatedSince() async throws {
        nonisolated(unsafe) var capturedURL: URL?

        TaskServiceMockURLProtocol.handler = { request in
            capturedURL = request.url
            return (Data("[]".utf8), makeResponse(statusCode: 200))
        }

        let (service, _) = try makeTaskService()
        let date = ISO8601DateFormatter().date(from: "2025-06-01T00:00:00Z")!
        _ = try await service.fetchTasks(playbookId: "pb-1", lane: .now, updatedSince: date)

        let urlString = capturedURL?.absoluteString ?? ""
        #expect(urlString.contains("lane=NOW"))
        #expect(urlString.contains("updated_since="))

        TaskServiceMockURLProtocol.handler = nil
    }

    @Test("fetchTasks server error throws TaskError.serverError")
    func fetchTasksServerError() async throws {
        let errorJSON = #"{"message":"Internal server error"}"#
        TaskServiceMockURLProtocol.handler = { _ in
            (Data(errorJSON.utf8), makeResponse(statusCode: 500))
        }

        let (service, _) = try makeTaskService()

        do {
            _ = try await service.fetchTasks(playbookId: "pb-1", lane: nil, updatedSince: nil)
            Issue.record("Expected TaskError.serverError")
        } catch let error as TaskError {
            guard case .serverError = error else {
                Issue.record("Expected serverError, got \(error)")
                return
            }
        }

        TaskServiceMockURLProtocol.handler = nil
    }

    // MARK: - Create (Optimistic)

    @Test("createTask creates via API and inserts into SwiftData with server ID")
    func createTaskSuccess() async throws {
        TaskServiceMockURLProtocol.handler = { _ in
            (Data(singleTaskJSON.utf8), makeResponse(statusCode: 201))
        }

        let (service, container) = try makeTaskService()
        let model = try await service.createTask(
            playbookId: "pb-1",
            title: "Write tests",
            detail: "Unit tests for TaskService",
            lane: .now,
            estimatedMinutes: 90
        )

        #expect(model.id == "task-1")
        #expect(model.title == "Write tests")
        #expect(model.lane == .now)
        #expect(model.estimatedMinutes == 90)

        // Verify SwiftData has exactly 1 record with the server ID (temp removed).
        let context = await container.mainContext
        let descriptor = FetchDescriptor<TaskModel>()
        let persisted = try await context.fetch(descriptor)
        #expect(persisted.count == 1)
        #expect(persisted.first?.id == "task-1")

        TaskServiceMockURLProtocol.handler = nil
    }

    @Test("createTask rolls back optimistic insert on network failure")
    func createTaskOptimisticRollback() async throws {
        TaskServiceMockURLProtocol.handler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let (service, container) = try makeTaskService()

        do {
            _ = try await service.createTask(
                playbookId: "pb-1",
                title: "Should rollback",
                detail: nil,
                lane: .now,
                estimatedMinutes: 60
            )
            Issue.record("Expected TaskError.networkError")
        } catch let error as TaskError {
            guard case .networkError = error else {
                Issue.record("Expected networkError, got \(error)")
                return
            }
        }

        // Verify SwiftData is empty (optimistic insert was rolled back).
        let context = await container.mainContext
        let descriptor = FetchDescriptor<TaskModel>()
        let persisted = try await context.fetch(descriptor)
        #expect(persisted.count == 0)

        TaskServiceMockURLProtocol.handler = nil
    }

    @Test("createTask network error throws TaskError.networkError")
    func createTaskNetworkError() async throws {
        TaskServiceMockURLProtocol.handler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let (service, _) = try makeTaskService()

        do {
            _ = try await service.createTask(
                playbookId: "pb-1",
                title: "Test",
                detail: nil,
                lane: .later,
                estimatedMinutes: 30
            )
            Issue.record("Expected TaskError.networkError")
        } catch let error as TaskError {
            guard case .networkError = error else {
                Issue.record("Expected networkError, got \(error)")
                return
            }
        }

        TaskServiceMockURLProtocol.handler = nil
    }

    // MARK: - Update

    @Test("updateTask patches via API and updates SwiftData")
    func updateTaskSuccess() async throws {
        let (service, container) = try makeTaskService()

        // Seed SwiftData with a task.
        let context = await container.mainContext
        let task = TaskModel(id: "task-1", playbookId: "pb-1", title: "Original Title", lane: .now)
        await context.insert(task)
        try await context.save()

        TaskServiceMockURLProtocol.handler = { _ in
            (Data(updatedSingleTaskJSON.utf8), makeResponse(statusCode: 200))
        }

        let dto = UpdateTaskDTO(title: "Patched Title", detail: "Patched detail", lane: "LATER", estimatedMinutes: 45, status: nil, orderIndex: nil)
        let model = try await service.updateTask(id: "task-1", dto: dto)

        #expect(model.title == "Patched Title")
        #expect(model.detail == "Patched detail")
        #expect(model.lane == .later)
        #expect(model.estimatedMinutes == 45)

        // Verify SwiftData reflects the update (no duplicates).
        let descriptor = FetchDescriptor<TaskModel>()
        let persisted = try await context.fetch(descriptor)
        #expect(persisted.count == 1)
        #expect(persisted.first?.title == "Patched Title")

        TaskServiceMockURLProtocol.handler = nil
    }

    // MARK: - Complete (Optimistic)

    @Test("completeTask marks done via API and updates SwiftData")
    func completeTaskSuccess() async throws {
        let (service, container) = try makeTaskService()

        // Seed SwiftData with an OPEN task.
        let context = await container.mainContext
        let task = TaskModel(id: "task-1", playbookId: "pb-1", title: "Task One", lane: .now)
        await context.insert(task)
        try await context.save()

        TaskServiceMockURLProtocol.handler = { _ in
            (Data(completedTaskJSON.utf8), makeResponse(statusCode: 200))
        }

        let model = try await service.completeTask(id: "task-1")

        #expect(model.status == .done)
        #expect(model.completedAt != nil)

        // Verify SwiftData reflects completion.
        let predicate = #Predicate<TaskModel> { $0.id == "task-1" }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        let persisted = try await context.fetch(descriptor).first
        #expect(persisted?.status == .done)
        #expect(persisted?.completedAt != nil)

        TaskServiceMockURLProtocol.handler = nil
    }

    @Test("completeTask rolls back to OPEN on server failure")
    func completeTaskRollbackOnFailure() async throws {
        let (service, container) = try makeTaskService()

        // Seed SwiftData with an OPEN task.
        let context = await container.mainContext
        let task = TaskModel(id: "task-1", playbookId: "pb-1", title: "Task One", lane: .now)
        await context.insert(task)
        try await context.save()

        let errorJSON = #"{"message":"Internal server error"}"#
        TaskServiceMockURLProtocol.handler = { _ in
            (Data(errorJSON.utf8), makeResponse(statusCode: 500))
        }

        do {
            _ = try await service.completeTask(id: "task-1")
            Issue.record("Expected TaskError.serverError")
        } catch let error as TaskError {
            guard case .serverError = error else {
                Issue.record("Expected serverError, got \(error)")
                return
            }
        }

        // Verify SwiftData task is still OPEN (rolled back).
        let predicate = #Predicate<TaskModel> { $0.id == "task-1" }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        let persisted = try await context.fetch(descriptor).first
        #expect(persisted?.status == .open)
        #expect(persisted?.completedAt == nil)

        TaskServiceMockURLProtocol.handler = nil
    }

    // MARK: - Reorder

    @Test("reorderTasks sends correct path and method")
    func reorderTasksSuccess() async throws {
        nonisolated(unsafe) var capturedPath: String?
        nonisolated(unsafe) var capturedMethod: String?

        TaskServiceMockURLProtocol.handler = { request in
            capturedPath = request.url?.path
            capturedMethod = request.httpMethod
            return (Data(), makeResponse(statusCode: 204))
        }

        let (service, _) = try makeTaskService()
        try await service.reorderTasks(playbookId: "pb-1", lane: .now, taskIds: ["task-2", "task-1"])

        #expect(capturedPath?.contains("/v1/tasks/reorder") == true)
        #expect(capturedMethod == "POST")

        TaskServiceMockURLProtocol.handler = nil
    }

    // MARK: - Delete

    @Test("deleteTask removes from SwiftData on success")
    func deleteTaskSuccess() async throws {
        let (service, container) = try makeTaskService()

        // Seed SwiftData with a task.
        let context = await container.mainContext
        let task = TaskModel(id: "task-1", playbookId: "pb-1", title: "To Delete", lane: .now)
        await context.insert(task)
        try await context.save()

        TaskServiceMockURLProtocol.handler = { _ in
            (Data(), makeResponse(statusCode: 204))
        }

        try await service.deleteTask(id: "task-1")

        // Verify the task is removed from SwiftData.
        let descriptor = FetchDescriptor<TaskModel>()
        let persisted = try await context.fetch(descriptor)
        #expect(persisted.count == 0)

        TaskServiceMockURLProtocol.handler = nil
    }

    @Test("deleteTask 404 throws TaskError.notFound")
    func deleteTaskNotFound() async throws {
        TaskServiceMockURLProtocol.handler = { _ in
            (Data(), makeResponse(statusCode: 404))
        }

        let (service, _) = try makeTaskService()

        do {
            try await service.deleteTask(id: "nonexistent")
            Issue.record("Expected TaskError.notFound")
        } catch let error as TaskError {
            #expect(error == .notFound)
        }

        TaskServiceMockURLProtocol.handler = nil
    }
}
