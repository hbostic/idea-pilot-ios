//
//  SectionDTO.swift
//  idea-pilot
//
//  Data transfer objects for Section API endpoints.
//

import Foundation

/// Response DTO for a Section from the API.
nonisolated struct SectionDTO: Codable, Sendable {
    let playbookId: String
    let sectionType: String
    let content: String
    let updatedAt: Date
}

/// Request body for `PUT /v1/playbooks/:id/sections/:type`.
nonisolated struct UpdateSectionDTO: Codable, Sendable {
    let content: String
}

// MARK: - Mapping

extension SectionDTO {

    /// Converts the DTO into a SwiftData model.
    @MainActor
    func toModel() -> SectionModel {
        SectionModel(
            playbookId: playbookId,
            sectionType: SectionType(rawValue: sectionType) ?? .vision,
            content: content,
            updatedAt: updatedAt
        )
    }
}

extension SectionModel {

    /// Creates a DTO for updating this section on the server.
    func toUpdateDTO() -> UpdateSectionDTO {
        UpdateSectionDTO(content: content)
    }
}
