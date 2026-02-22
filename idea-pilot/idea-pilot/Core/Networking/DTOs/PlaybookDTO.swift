//
//  PlaybookDTO.swift
//  idea-pilot
//
//  Data transfer objects for Playbook API endpoints.
//

import Foundation

/// Response DTO for a Playbook from the API.
nonisolated struct PlaybookDTO: Codable, Sendable {
    let id: String
    let title: String
    let description: String?
    let phase: String
    let isArchived: Bool
    let createdAt: Date
    let updatedAt: Date
    let tasks: [TaskDTO]?
    let sections: [SectionDTO]?
}

/// Request body for `POST /v1/playbooks`.
nonisolated struct CreatePlaybookDTO: Codable, Sendable {
    let title: String
    let description: String?
    let phase: String
}

/// Request body for `PATCH /v1/playbooks/:id`.
nonisolated struct UpdatePlaybookDTO: Codable, Sendable {
    let title: String?
    let description: String?
    let phase: String?
    let isArchived: Bool?
}

// MARK: - Mapping

extension PlaybookDTO {

    /// Converts the DTO into a SwiftData model.
    @MainActor
    func toModel() -> PlaybookModel {
        PlaybookModel(
            id: id,
            title: title,
            descriptionText: description,
            phase: PlaybookPhase(rawValue: phase) ?? .proof,
            isArchived: isArchived,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

extension PlaybookModel {

    /// Creates a DTO for creating a new playbook on the server.
    func toCreateDTO() -> CreatePlaybookDTO {
        CreatePlaybookDTO(
            title: title,
            description: descriptionText,
            phase: phase.rawValue
        )
    }

    /// Creates a DTO for updating an existing playbook on the server.
    func toUpdateDTO() -> UpdatePlaybookDTO {
        UpdatePlaybookDTO(
            title: title,
            description: descriptionText,
            phase: phase.rawValue,
            isArchived: isArchived
        )
    }
}
