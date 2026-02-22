//
//  TaskDTO.swift
//  idea-pilot
//
//  Data transfer objects for Task API endpoints.
//

import Foundation

/// Response DTO for a Task from the API.
nonisolated struct TaskDTO: Codable, Sendable {
    let id: String
    let playbookId: String
    let title: String
    let detail: String?
    let lane: String
    let estimatedMinutes: Int
    let status: String
    let orderIndex: Int
    let completedAt: Date?
    let createdAt: Date
    let updatedAt: Date
}

/// Request body for `POST /v1/tasks`.
nonisolated struct CreateTaskDTO: Codable, Sendable {
    let playbookId: String
    let title: String
    let detail: String?
    let lane: String
    let estimatedMinutes: Int
}

/// Request body for `PATCH /v1/tasks/:id`.
nonisolated struct UpdateTaskDTO: Codable, Sendable {
    let title: String?
    let detail: String?
    let lane: String?
    let estimatedMinutes: Int?
    let status: String?
    let orderIndex: Int?
}

/// Request body for `POST /v1/tasks/reorder`.
nonisolated struct ReorderTasksDTO: Codable, Sendable {
    let playbookId: String
    let lane: String
    let taskIds: [String]
}

// MARK: - Mapping

extension TaskDTO {

    /// Converts the DTO into a SwiftData model.
    @MainActor
    func toModel() -> TaskModel {
        TaskModel(
            id: id,
            playbookId: playbookId,
            title: title,
            detail: detail,
            lane: TaskLane(rawValue: lane) ?? .later,
            estimatedMinutes: estimatedMinutes,
            status: TaskStatus(rawValue: status) ?? .open,
            orderIndex: orderIndex,
            completedAt: completedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

extension TaskModel {

    /// Creates a DTO for creating a new task on the server.
    func toCreateDTO() -> CreateTaskDTO {
        CreateTaskDTO(
            playbookId: playbookId,
            title: title,
            detail: detail,
            lane: lane.rawValue,
            estimatedMinutes: estimatedMinutes
        )
    }

    /// Creates a DTO for updating an existing task on the server.
    func toUpdateDTO() -> UpdateTaskDTO {
        UpdateTaskDTO(
            title: title,
            detail: detail,
            lane: lane.rawValue,
            estimatedMinutes: estimatedMinutes,
            status: status.rawValue,
            orderIndex: orderIndex
        )
    }
}
