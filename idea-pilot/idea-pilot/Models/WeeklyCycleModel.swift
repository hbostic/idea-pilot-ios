//
//  WeeklyCycleModel.swift
//  idea-pilot
//
//  SwiftData model for a WeeklyCycle — a weekly planning snapshot for a Playbook.
//

import Foundation
import SwiftData

/// A weekly planning cycle snapshot belonging to a Playbook.
///
/// Tracks how many tasks were planned vs. completed for a given week.
/// Used by the Weekly Plan ritual flow and progress dashboards.
///
/// Relationship: belongs to one `PlaybookModel`.
@Model
final class WeeklyCycleModel {

    /// Server-assigned unique identifier.
    @Attribute(.unique) var id: String

    /// The ID of the parent playbook (denormalized for queries).
    var playbookId: String

    /// The Monday start date of this planning week.
    var weekStartDate: Date

    /// Number of tasks completed this week.
    var completedCount: Int

    /// Total number of tasks planned for this week.
    var totalCount: Int

    var createdAt: Date
    var updatedAt: Date

    /// The parent playbook.
    var playbook: PlaybookModel?

    init(
        id: String = UUID().uuidString,
        playbookId: String,
        weekStartDate: Date,
        completedCount: Int = 0,
        totalCount: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.playbookId = playbookId
        self.weekStartDate = weekStartDate
        self.completedCount = completedCount
        self.totalCount = totalCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
