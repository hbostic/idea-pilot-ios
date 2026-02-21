//
//  PlaybookModel.swift
//  idea-pilot
//
//  SwiftData model for a Playbook — the top-level project container.
//

import Foundation
import SwiftData

/// A project container that holds vision, system, build sections and executable tasks.
///
/// Each Playbook progresses through lifecycle phases (PROOF → STRUCTURE → REPEATABILITY → GROWTH)
/// and contains tasks organized into NOW/NEXT/LATER lanes.
///
/// Relationships:
/// - One-to-many with `TaskModel` (cascade delete)
/// - One-to-many with `SectionModel` (cascade delete)
/// - One-to-many with `WeeklyCycleModel` (cascade delete)
@Model
final class PlaybookModel {

    /// Server-assigned unique identifier.
    @Attribute(.unique) var id: String

    /// The playbook's display title.
    var title: String

    /// Optional longer description of the playbook's purpose.
    var descriptionText: String?

    /// The current lifecycle phase, stored as its raw string value.
    var phaseRawValue: String

    /// Whether this playbook has been archived by the user.
    var isArchived: Bool

    var createdAt: Date
    var updatedAt: Date

    /// All tasks belonging to this playbook.
    @Relationship(deleteRule: .cascade, inverse: \TaskModel.playbook)
    var tasks: [TaskModel]

    /// The immutable sections (Vision, System, Build, Business Model).
    @Relationship(deleteRule: .cascade, inverse: \SectionModel.playbook)
    var sections: [SectionModel]

    /// Weekly planning cycles for this playbook.
    @Relationship(deleteRule: .cascade, inverse: \WeeklyCycleModel.playbook)
    var weeklyCycles: [WeeklyCycleModel]

    /// The current lifecycle phase.
    var phase: PlaybookPhase {
        get { PlaybookPhase(rawValue: phaseRawValue) ?? .proof }
        set { phaseRawValue = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        descriptionText: String? = nil,
        phase: PlaybookPhase = .proof,
        isArchived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.descriptionText = descriptionText
        self.phaseRawValue = phase.rawValue
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tasks = []
        self.sections = []
        self.weeklyCycles = []
    }
}
