//
//  SectionModel.swift
//  idea-pilot
//
//  SwiftData model for a Section — a structured content block within a Playbook.
//

import Foundation
import SwiftData

/// A structured content section belonging to a Playbook.
///
/// Each Playbook has one section per `SectionType` (Vision, System, Build, Business Model).
/// The `compositeId` uniquely identifies a section as `"{playbookId}_{sectionType}"`.
///
/// Relationship: belongs to one `PlaybookModel`.
@Model
final class SectionModel {

    /// Composite unique key: `"{playbookId}_{sectionType}"`.
    @Attribute(.unique) var compositeId: String

    /// The ID of the parent playbook (denormalized for queries).
    var playbookId: String

    /// The section type, stored as its raw string value.
    var sectionTypeRawValue: String

    /// The rich text content of this section.
    var content: String

    var updatedAt: Date

    /// The parent playbook.
    var playbook: PlaybookModel?

    /// The section type (VISION/SYSTEM/BUILD/BUSINESS_MODEL).
    var sectionType: SectionType {
        get { SectionType(rawValue: sectionTypeRawValue) ?? .vision }
        set { sectionTypeRawValue = newValue.rawValue }
    }

    init(
        playbookId: String,
        sectionType: SectionType,
        content: String = "",
        updatedAt: Date = .now
    ) {
        self.compositeId = "\(playbookId)_\(sectionType.rawValue)"
        self.playbookId = playbookId
        self.sectionTypeRawValue = sectionType.rawValue
        self.content = content
        self.updatedAt = updatedAt
    }
}
