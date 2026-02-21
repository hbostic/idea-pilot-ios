//
//  TaskModel.swift
//  idea-pilot
//
//  SwiftData model for a Task — an executable work item within a Playbook.
//

import Foundation
import SwiftData

/// An executable work item belonging to a Playbook.
///
/// Tasks are organized into lanes (NOW/NEXT/LATER) and must be sized between
/// 30–180 minutes. The `orderIndex` determines display order within a lane.
///
/// Relationship: belongs to one `PlaybookModel`.
@Model
final class TaskModel {

    /// Server-assigned unique identifier.
    @Attribute(.unique) var id: String

    /// The ID of the parent playbook (denormalized for queries).
    var playbookId: String

    /// The task's display title.
    var title: String

    /// Optional longer description or notes.
    var detail: String?

    /// The execution lane, stored as its raw string value.
    var laneRawValue: String

    /// Estimated duration in minutes (30–180).
    var estimatedMinutes: Int

    /// The completion status, stored as its raw string value.
    var statusRawValue: String

    /// Display order within the lane (0-indexed).
    var orderIndex: Int

    /// When the task was marked as done.
    var completedAt: Date?

    var createdAt: Date
    var updatedAt: Date

    /// The parent playbook.
    var playbook: PlaybookModel?

    /// The execution lane (NOW/NEXT/LATER).
    var lane: TaskLane {
        get { TaskLane(rawValue: laneRawValue) ?? .later }
        set { laneRawValue = newValue.rawValue }
    }

    /// The completion status (OPEN/DONE).
    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRawValue) ?? .open }
        set { statusRawValue = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        playbookId: String,
        title: String,
        detail: String? = nil,
        lane: TaskLane = .later,
        estimatedMinutes: Int = 60,
        status: TaskStatus = .open,
        orderIndex: Int = 0,
        completedAt: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.playbookId = playbookId
        self.title = title
        self.detail = detail
        self.laneRawValue = lane.rawValue
        self.estimatedMinutes = estimatedMinutes
        self.statusRawValue = status.rawValue
        self.orderIndex = orderIndex
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
