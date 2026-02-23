//
//  TaskService.swift
//  idea-pilot
//
//  Service handling task API calls and SwiftData persistence.
//  Supports fetch (with incremental sync), create (optimistic), update,
//  complete (optimistic), reorder, and delete operations.
//

import Foundation
import SwiftData

// MARK: - TaskError

/// Errors specific to task operations.
nonisolated enum TaskError: Error, Equatable, Sendable {
    /// The requested task was not found (404).
    case notFound
    /// A network-level failure occurred.
    case networkError(String)
    /// The server returned an unexpected error.
    case serverError(String)
}

// MARK: - TaskServiceProtocol

/// Defines the task API surface for testability.
nonisolated protocol TaskServiceProtocol: Sendable {
    /// Fetches tasks from the API, upserts into SwiftData, and returns the models.
    /// Falls back to cached SwiftData data when offline.
    func fetchTasks(playbookId: String, lane: TaskLane?, updatedSince: Date?) async throws -> [TaskModel]

    /// Creates a new task optimistically (inserts locally first, then syncs with API).
    func createTask(playbookId: String, title: String, detail: String?, lane: TaskLane, estimatedMinutes: Int) async throws -> TaskModel

    /// Updates task fields on the server and in SwiftData.
    func updateTask(id: String, dto: UpdateTaskDTO) async throws -> TaskModel

    /// Marks a task as done (optimistic — updates locally, then syncs).
    func completeTask(id: String) async throws -> TaskModel

    /// Sends a full ordered ID list to reorder tasks within a lane.
    func reorderTasks(playbookId: String, lane: TaskLane, taskIds: [String]) async throws

    /// Deletes a task on the server and removes it from SwiftData.
    func deleteTask(id: String) async throws
}

// MARK: - TaskService

/// Coordinates task CRUD through `APIClient` and SwiftData.
///
/// Each operation follows one of two patterns:
/// - **Standard**: Call the API → update SwiftData → return model(s)
/// - **Optimistic**: Update SwiftData → call the API → reconcile on success / rollback on failure
///
/// `fetchTasks` supports offline fallback by reading from SwiftData cache
/// when the network is unavailable.
final class TaskService: TaskServiceProtocol, Sendable {

    private let apiClient: APIClient
    private let modelContainer: ModelContainer

    /// Creates a TaskService.
    ///
    /// - Parameters:
    ///   - apiClient: The networking client for API calls.
    ///   - modelContainer: The SwiftData container for local persistence.
    init(apiClient: APIClient, modelContainer: ModelContainer) {
        self.apiClient = apiClient
        self.modelContainer = modelContainer
    }

    func fetchTasks(playbookId: String, lane: TaskLane? = nil, updatedSince: Date? = nil) async throws -> [TaskModel] {
        do {
            let dtos: [TaskDTO] = try await apiClient.request(
                .getTasks(playbookId: playbookId, lane: lane?.rawValue, updatedSince: updatedSince)
            )
            return try await upsertTasks(dtos)
        } catch let error as APIError {
            if error.isOffline {
                return try await cachedTasks(playbookId: playbookId, lane: lane)
            }
            throw mapError(error)
        } catch let error as TaskError {
            throw error
        } catch {
            throw TaskError.serverError(error.localizedDescription)
        }
    }

    func createTask(
        playbookId: String,
        title: String,
        detail: String?,
        lane: TaskLane,
        estimatedMinutes: Int
    ) async throws -> TaskModel {
        // 1. Insert optimistically with a temp ID.
        let tempId = try await insertOptimisticTask(
            playbookId: playbookId,
            title: title,
            detail: detail,
            lane: lane,
            estimatedMinutes: estimatedMinutes
        )

        // 2. Call API.
        let dto = CreateTaskDTO(
            playbookId: playbookId,
            title: title,
            detail: detail,
            lane: lane.rawValue,
            estimatedMinutes: estimatedMinutes
        )

        do {
            let response: TaskDTO = try await apiClient.request(.createTask(dto: dto))
            // 3. On success: reconcile local model with server response.
            return try await reconcileCreatedTask(tempId: tempId, dto: response)
        } catch {
            // 4. On failure: rollback (delete the optimistic insert).
            try await rollbackTask(tempId: tempId)
            if let apiError = error as? APIError {
                throw mapError(apiError)
            }
            throw TaskError.serverError(error.localizedDescription)
        }
    }

    func updateTask(id: String, dto: UpdateTaskDTO) async throws -> TaskModel {
        do {
            let response: TaskDTO = try await apiClient.request(.updateTask(id: id, dto: dto))
            return try await upsertSingleTask(response)
        } catch let error as APIError {
            throw mapError(error)
        } catch let error as TaskError {
            throw error
        } catch {
            throw TaskError.serverError(error.localizedDescription)
        }
    }

    func completeTask(id: String) async throws -> TaskModel {
        // Optimistically mark done locally.
        let previousState = try await markTaskDone(id: id)

        do {
            let response: TaskDTO = try await apiClient.request(.completeTask(id: id))
            // Reconcile with server response (server sets canonical completedAt).
            return try await upsertSingleTask(response)
        } catch {
            // Rollback on failure.
            try await restoreTaskState(id: id, previousState: previousState)
            if let apiError = error as? APIError {
                throw mapError(apiError)
            }
            throw TaskError.serverError(error.localizedDescription)
        }
    }

    func reorderTasks(playbookId: String, lane: TaskLane, taskIds: [String]) async throws {
        let dto = ReorderTasksDTO(playbookId: playbookId, lane: lane.rawValue, taskIds: taskIds)
        do {
            try await apiClient.requestVoid(.reorderTasks(dto: dto))
            try await updateLocalOrder(taskIds: taskIds)
        } catch let error as APIError {
            throw mapError(error)
        } catch let error as TaskError {
            throw error
        } catch {
            throw TaskError.serverError(error.localizedDescription)
        }
    }

    func deleteTask(id: String) async throws {
        do {
            try await apiClient.requestVoid(.deleteTask(id: id))
            try await removeTask(id: id)
        } catch let error as APIError {
            throw mapError(error)
        } catch let error as TaskError {
            throw error
        } catch {
            throw TaskError.serverError(error.localizedDescription)
        }
    }

    // MARK: - Private — SwiftData Operations

    /// Upserts an array of task DTOs into SwiftData.
    @MainActor
    private func upsertTasks(_ dtos: [TaskDTO]) throws -> [TaskModel] {
        let context = modelContainer.mainContext
        var models: [TaskModel] = []

        for dto in dtos {
            let predicate = #Predicate<TaskModel> { $0.id == dto.id }
            var descriptor = FetchDescriptor(predicate: predicate)
            descriptor.fetchLimit = 1

            if let existing = try context.fetch(descriptor).first {
                existing.title = dto.title
                existing.detail = dto.detail
                existing.laneRawValue = dto.lane
                existing.estimatedMinutes = dto.estimatedMinutes
                existing.statusRawValue = dto.status
                existing.orderIndex = dto.orderIndex
                existing.completedAt = dto.completedAt
                existing.updatedAt = dto.updatedAt
                models.append(existing)
            } else {
                let model = dto.toModel()
                context.insert(model)
                models.append(model)
            }
        }

        try context.save()
        return models
    }

    /// Upserts a single task DTO into SwiftData.
    @MainActor
    private func upsertSingleTask(_ dto: TaskDTO) throws -> TaskModel {
        try upsertTasks([dto]).first!
    }

    /// Inserts a task model optimistically with a temporary ID. Returns the temp ID.
    @MainActor
    private func insertOptimisticTask(
        playbookId: String,
        title: String,
        detail: String?,
        lane: TaskLane,
        estimatedMinutes: Int
    ) throws -> String {
        let context = modelContainer.mainContext
        let model = TaskModel(
            playbookId: playbookId,
            title: title,
            detail: detail,
            lane: lane,
            estimatedMinutes: estimatedMinutes
        )
        context.insert(model)
        try context.save()
        return model.id
    }

    /// Replaces the optimistic model with the server-truth model.
    @MainActor
    private func reconcileCreatedTask(tempId: String, dto: TaskDTO) throws -> TaskModel {
        let context = modelContainer.mainContext

        // Delete the temp model.
        let predicate = #Predicate<TaskModel> { $0.id == tempId }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        if let temp = try context.fetch(descriptor).first {
            context.delete(temp)
        }

        // Insert the server-truth model.
        let model = dto.toModel()
        context.insert(model)
        try context.save()
        return model
    }

    /// Deletes the optimistic model on API failure.
    @MainActor
    private func rollbackTask(tempId: String) throws {
        let context = modelContainer.mainContext
        let predicate = #Predicate<TaskModel> { $0.id == tempId }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        if let temp = try context.fetch(descriptor).first {
            context.delete(temp)
            try context.save()
        }
    }

    /// Marks a task as done and returns its previous state for rollback.
    @MainActor
    private func markTaskDone(id: String) throws -> TaskPreviousState {
        let context = modelContainer.mainContext
        let predicate = #Predicate<TaskModel> { $0.id == id }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        guard let model = try context.fetch(descriptor).first else {
            throw TaskError.notFound
        }

        let previous = TaskPreviousState(
            statusRawValue: model.statusRawValue,
            completedAt: model.completedAt
        )

        model.status = .done
        model.completedAt = .now
        try context.save()

        return previous
    }

    /// Restores a task to its previous state after a failed API call.
    @MainActor
    private func restoreTaskState(id: String, previousState: TaskPreviousState) throws {
        let context = modelContainer.mainContext
        let predicate = #Predicate<TaskModel> { $0.id == id }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        guard let model = try context.fetch(descriptor).first else { return }
        model.statusRawValue = previousState.statusRawValue
        model.completedAt = previousState.completedAt
        try context.save()
    }

    /// Updates local orderIndex values after a successful reorder.
    @MainActor
    private func updateLocalOrder(taskIds: [String]) throws {
        let context = modelContainer.mainContext

        for (index, taskId) in taskIds.enumerated() {
            let predicate = #Predicate<TaskModel> { $0.id == taskId }
            var descriptor = FetchDescriptor(predicate: predicate)
            descriptor.fetchLimit = 1
            if let model = try context.fetch(descriptor).first {
                model.orderIndex = index
            }
        }

        try context.save()
    }

    /// Removes a task from SwiftData.
    @MainActor
    private func removeTask(id: String) throws {
        let context = modelContainer.mainContext
        let predicate = #Predicate<TaskModel> { $0.id == id }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        guard let model = try context.fetch(descriptor).first else { return }
        context.delete(model)
        try context.save()
    }

    /// Returns cached tasks from SwiftData (offline fallback).
    @MainActor
    private func cachedTasks(playbookId: String, lane: TaskLane?) throws -> [TaskModel] {
        let context = modelContainer.mainContext
        let predicate: Predicate<TaskModel>
        if let laneRaw = lane?.rawValue {
            predicate = #Predicate<TaskModel> { $0.playbookId == playbookId && $0.laneRawValue == laneRaw }
        } else {
            predicate = #Predicate<TaskModel> { $0.playbookId == playbookId }
        }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.orderIndex)])
        return try context.fetch(descriptor)
    }

    // MARK: - Private — Error Mapping

    private func mapError(_ error: APIError) -> TaskError {
        switch error {
        case .notFound:
            return .notFound
        case .networkError(let urlError):
            return .networkError(urlError.localizedDescription)
        case .offline:
            return .networkError("No internet connection")
        case .serverError(_, let message):
            return .serverError(message ?? "Server error")
        case .badRequest(let message):
            return .serverError(message ?? "Bad request")
        case .sessionExpired:
            return .serverError("Session expired")
        case .decodingError(let message):
            return .serverError("Invalid response: \(message)")
        }
    }
}

// MARK: - TaskPreviousState

/// Captures task state before an optimistic mutation for potential rollback.
private struct TaskPreviousState {
    let statusRawValue: String
    let completedAt: Date?
}
