//
//  WeeklyCycleDTO.swift
//  idea-pilot
//
//  Data transfer objects for WeeklyCycle API endpoints.
//

import Foundation

/// Response DTO for a WeeklyCycle from the API.
nonisolated struct WeeklyCycleDTO: Codable, Sendable {
    let id: String
    let playbookId: String
    let weekStartDate: Date
    let completedCount: Int
    let totalCount: Int
    let createdAt: Date
    let updatedAt: Date
}

// MARK: - Mapping

extension WeeklyCycleDTO {

    /// Converts the DTO into a SwiftData model.
    @MainActor
    func toModel() -> WeeklyCycleModel {
        WeeklyCycleModel(
            id: id,
            playbookId: playbookId,
            weekStartDate: weekStartDate,
            completedCount: completedCount,
            totalCount: totalCount,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
