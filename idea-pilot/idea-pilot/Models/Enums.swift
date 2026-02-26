//
//  Enums.swift
//  idea-pilot
//
//  Domain enums for Playbook phase, Task lane/status, and Section type.
//  Raw values match the backend API contract.
//

import SwiftUI

// MARK: - Playbook Phase

/// The lifecycle phase of a Playbook.
///
/// Projects progress sequentially: prove the idea manually, formalize what worked,
/// make it teachable/delegable, then scale.
///
/// Raw values match the backend API: `"PROOF"`, `"STRUCTURE"`, etc.
enum PlaybookPhase: String, Codable, Hashable, CaseIterable, Sendable {
    case proof = "PROOF"
    case structure = "STRUCTURE"
    case repeatability = "REPEATABILITY"
    case growth = "GROWTH"

    /// The design system color for this phase.
    var color: Color {
        switch self {
        case .proof:         return Color.theme.phaseProof
        case .structure:     return Color.theme.phaseStructure
        case .repeatability: return Color.theme.phaseRepeatability
        case .growth:        return Color.theme.phaseGrowth
        }
    }
}

// MARK: - Task Lane

/// The execution lane for a Task.
///
/// - `now`: Active tasks (daily focus, 3–5 max)
/// - `next`: Upcoming tasks
/// - `later`: Backlog / idea parking lot
enum TaskLane: String, Codable, Hashable, CaseIterable, Sendable {
    case now = "NOW"
    case next = "NEXT"
    case later = "LATER"
}

// MARK: - Task Status

/// The completion status of a Task.
enum TaskStatus: String, Codable, Hashable, CaseIterable, Sendable {
    case open = "OPEN"
    case done = "DONE"
}

// MARK: - Section Type

/// The type of an immutable Playbook section.
///
/// Each Playbook has exactly one of each section type.
/// Content is rich text edited by the user.
enum SectionType: String, Codable, Hashable, CaseIterable, Sendable {
    case vision = "VISION"
    case system = "SYSTEM"
    case build = "BUILD"
    case businessModel = "BUSINESS_MODEL"

    /// Human-readable display name for the UI.
    var displayName: String {
        switch self {
        case .vision: "Vision"
        case .system: "System"
        case .build: "Build"
        case .businessModel: "Business Model"
        }
    }
}
