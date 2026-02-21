//
//  ModelTests.swift
//  idea-pilotTests
//
//  Unit tests for SwiftData domain models and enums.
//

import Foundation
import SwiftData
import Testing
@testable import idea_pilot

// MARK: - Enum Tests

@Suite("PlaybookPhase")
struct PlaybookPhaseTests {

    @Test("raw values match API contract")
    func rawValues() {
        #expect(PlaybookPhase.proof.rawValue == "PROOF")
        #expect(PlaybookPhase.structure.rawValue == "STRUCTURE")
        #expect(PlaybookPhase.repeatability.rawValue == "REPEATABILITY")
        #expect(PlaybookPhase.growth.rawValue == "GROWTH")
    }

    @Test("CaseIterable returns all four phases")
    func allCases() {
        #expect(PlaybookPhase.allCases.count == 4)
    }

    @Test("Codable roundtrip")
    func codableRoundtrip() throws {
        for phase in PlaybookPhase.allCases {
            let data = try JSONEncoder().encode(phase)
            let decoded = try JSONDecoder().decode(PlaybookPhase.self, from: data)
            #expect(decoded == phase)
        }
    }
}

@Suite("TaskLane")
struct TaskLaneTests {

    @Test("raw values match API contract")
    func rawValues() {
        #expect(TaskLane.now.rawValue == "NOW")
        #expect(TaskLane.next.rawValue == "NEXT")
        #expect(TaskLane.later.rawValue == "LATER")
    }

    @Test("CaseIterable returns all three lanes")
    func allCases() {
        #expect(TaskLane.allCases.count == 3)
    }

    @Test("Codable roundtrip")
    func codableRoundtrip() throws {
        for lane in TaskLane.allCases {
            let data = try JSONEncoder().encode(lane)
            let decoded = try JSONDecoder().decode(TaskLane.self, from: data)
            #expect(decoded == lane)
        }
    }
}

@Suite("TaskStatus")
struct TaskStatusTests {

    @Test("raw values match API contract")
    func rawValues() {
        #expect(TaskStatus.open.rawValue == "OPEN")
        #expect(TaskStatus.done.rawValue == "DONE")
    }

    @Test("CaseIterable returns both statuses")
    func allCases() {
        #expect(TaskStatus.allCases.count == 2)
    }

    @Test("Codable roundtrip")
    func codableRoundtrip() throws {
        for status in TaskStatus.allCases {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(TaskStatus.self, from: data)
            #expect(decoded == status)
        }
    }
}

@Suite("SectionType")
struct SectionTypeTests {

    @Test("raw values match API contract")
    func rawValues() {
        #expect(SectionType.vision.rawValue == "VISION")
        #expect(SectionType.system.rawValue == "SYSTEM")
        #expect(SectionType.build.rawValue == "BUILD")
        #expect(SectionType.businessModel.rawValue == "BUSINESS_MODEL")
    }

    @Test("CaseIterable returns all four types")
    func allCases() {
        #expect(SectionType.allCases.count == 4)
    }

    @Test("Codable roundtrip")
    func codableRoundtrip() throws {
        for sType in SectionType.allCases {
            let data = try JSONEncoder().encode(sType)
            let decoded = try JSONDecoder().decode(SectionType.self, from: data)
            #expect(decoded == sType)
        }
    }
}

@Suite("UserSession")
struct UserSessionTests {

    @Test("Codable roundtrip")
    func codableRoundtrip() throws {
        let session = UserSession(
            userId: "user-123",
            email: "test@example.com",
            accessToken: "access-xyz",
            refreshToken: "refresh-abc"
        )
        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(UserSession.self, from: data)
        #expect(decoded == session)
    }
}

// MARK: - Model Tests

/// Creates an in-memory ModelContainer for testing.
@MainActor
private func makeTestContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: PlaybookModel.self, TaskModel.self, SectionModel.self, WeeklyCycleModel.self,
        configurations: config
    )
}

@Suite("PlaybookModel CRUD", .serialized)
@MainActor
struct PlaybookModelTests {

    @Test("create and fetch")
    func createAndFetch() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let playbook = PlaybookModel(id: "pb-1", title: "Launch MVP", phase: .proof)
        context.insert(playbook)
        try context.save()

        let descriptor = FetchDescriptor<PlaybookModel>()
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results[0].title == "Launch MVP")
        #expect(results[0].phase == .proof)
        #expect(results[0].isArchived == false)
    }

    @Test("update fields")
    func updateFields() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let playbook = PlaybookModel(id: "pb-2", title: "Old Title", phase: .proof)
        context.insert(playbook)
        try context.save()

        playbook.title = "New Title"
        playbook.phase = .structure
        try context.save()

        let descriptor = FetchDescriptor<PlaybookModel>()
        let results = try context.fetch(descriptor)
        #expect(results[0].title == "New Title")
        #expect(results[0].phase == .structure)
    }

    @Test("delete")
    func delete() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let playbook = PlaybookModel(id: "pb-3", title: "To Delete")
        context.insert(playbook)
        try context.save()

        context.delete(playbook)
        try context.save()

        let descriptor = FetchDescriptor<PlaybookModel>()
        let results = try context.fetch(descriptor)
        #expect(results.isEmpty)
    }
}

@Suite("TaskModel CRUD", .serialized)
@MainActor
struct TaskModelTests {

    @Test("create and fetch")
    func createAndFetch() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let task = TaskModel(
            id: "t-1",
            playbookId: "pb-1",
            title: "Write tests",
            lane: .now,
            estimatedMinutes: 90,
            status: .open
        )
        context.insert(task)
        try context.save()

        let descriptor = FetchDescriptor<TaskModel>()
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results[0].title == "Write tests")
        #expect(results[0].lane == .now)
        #expect(results[0].estimatedMinutes == 90)
        #expect(results[0].status == .open)
    }

    @Test("update status to done")
    func updateStatus() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let task = TaskModel(id: "t-2", playbookId: "pb-1", title: "Task")
        context.insert(task)
        try context.save()

        task.status = .done
        task.completedAt = .now
        try context.save()

        let descriptor = FetchDescriptor<TaskModel>()
        let results = try context.fetch(descriptor)
        #expect(results[0].status == .done)
        #expect(results[0].completedAt != nil)
    }

    @Test("delete")
    func delete() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let task = TaskModel(id: "t-3", playbookId: "pb-1", title: "To Delete")
        context.insert(task)
        try context.save()

        context.delete(task)
        try context.save()

        let descriptor = FetchDescriptor<TaskModel>()
        let results = try context.fetch(descriptor)
        #expect(results.isEmpty)
    }
}

@Suite("SectionModel CRUD", .serialized)
@MainActor
struct SectionModelTests {

    @Test("create and fetch")
    func createAndFetch() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let section = SectionModel(
            playbookId: "pb-1",
            sectionType: .vision,
            content: "Build the best app"
        )
        context.insert(section)
        try context.save()

        let descriptor = FetchDescriptor<SectionModel>()
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results[0].sectionType == .vision)
        #expect(results[0].content == "Build the best app")
        #expect(results[0].compositeId == "pb-1_VISION")
    }

    @Test("update content")
    func updateContent() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let section = SectionModel(playbookId: "pb-1", sectionType: .build, content: "v1")
        context.insert(section)
        try context.save()

        section.content = "v2 — updated"
        try context.save()

        let descriptor = FetchDescriptor<SectionModel>()
        let results = try context.fetch(descriptor)
        #expect(results[0].content == "v2 — updated")
    }

    @Test("delete")
    func delete() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let section = SectionModel(playbookId: "pb-1", sectionType: .system)
        context.insert(section)
        try context.save()

        context.delete(section)
        try context.save()

        let descriptor = FetchDescriptor<SectionModel>()
        let results = try context.fetch(descriptor)
        #expect(results.isEmpty)
    }
}

@Suite("WeeklyCycleModel CRUD", .serialized)
@MainActor
struct WeeklyCycleModelTests {

    @Test("create and fetch")
    func createAndFetch() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let cycle = WeeklyCycleModel(
            id: "wc-1",
            playbookId: "pb-1",
            weekStartDate: Date(timeIntervalSince1970: 1_700_000_000),
            completedCount: 3,
            totalCount: 5
        )
        context.insert(cycle)
        try context.save()

        let descriptor = FetchDescriptor<WeeklyCycleModel>()
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results[0].completedCount == 3)
        #expect(results[0].totalCount == 5)
    }

    @Test("delete")
    func delete() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let cycle = WeeklyCycleModel(
            id: "wc-2",
            playbookId: "pb-1",
            weekStartDate: .now
        )
        context.insert(cycle)
        try context.save()

        context.delete(cycle)
        try context.save()

        let descriptor = FetchDescriptor<WeeklyCycleModel>()
        let results = try context.fetch(descriptor)
        #expect(results.isEmpty)
    }
}

@Suite("Model Relationships", .serialized)
@MainActor
struct RelationshipTests {

    @Test("playbook → tasks relationship")
    func playbookTasks() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let playbook = PlaybookModel(id: "pb-rel-1", title: "Rel Test")
        context.insert(playbook)

        let task = TaskModel(id: "t-rel-1", playbookId: "pb-rel-1", title: "Task 1")
        task.playbook = playbook
        context.insert(task)
        try context.save()

        #expect(playbook.tasks.count == 1)
        #expect(task.playbook?.id == "pb-rel-1")
    }

    @Test("playbook → sections relationship")
    func playbookSections() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let playbook = PlaybookModel(id: "pb-rel-2", title: "Sections Test")
        context.insert(playbook)

        let section = SectionModel(playbookId: "pb-rel-2", sectionType: .vision, content: "Vision text")
        section.playbook = playbook
        context.insert(section)
        try context.save()

        #expect(playbook.sections.count == 1)
        #expect(section.playbook?.id == "pb-rel-2")
    }

    @Test("playbook → weeklyCycles relationship")
    func playbookWeeklyCycles() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let playbook = PlaybookModel(id: "pb-rel-3", title: "Cycles Test")
        context.insert(playbook)

        let cycle = WeeklyCycleModel(id: "wc-rel-1", playbookId: "pb-rel-3", weekStartDate: .now)
        cycle.playbook = playbook
        context.insert(cycle)
        try context.save()

        #expect(playbook.weeklyCycles.count == 1)
        #expect(cycle.playbook?.id == "pb-rel-3")
    }

    @Test("cascade delete removes tasks")
    func cascadeDeleteTasks() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let playbook = PlaybookModel(id: "pb-cas-1", title: "Cascade Test")
        context.insert(playbook)

        let task1 = TaskModel(id: "t-cas-1", playbookId: "pb-cas-1", title: "Task A")
        task1.playbook = playbook
        context.insert(task1)

        let task2 = TaskModel(id: "t-cas-2", playbookId: "pb-cas-1", title: "Task B")
        task2.playbook = playbook
        context.insert(task2)
        try context.save()

        #expect(playbook.tasks.count == 2)

        context.delete(playbook)
        try context.save()

        let taskDescriptor = FetchDescriptor<TaskModel>()
        let remainingTasks = try context.fetch(taskDescriptor)
        #expect(remainingTasks.isEmpty)
    }

    @Test("cascade delete removes sections")
    func cascadeDeleteSections() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let playbook = PlaybookModel(id: "pb-cas-2", title: "Cascade Sections")
        context.insert(playbook)

        let section = SectionModel(playbookId: "pb-cas-2", sectionType: .build, content: "Content")
        section.playbook = playbook
        context.insert(section)
        try context.save()

        context.delete(playbook)
        try context.save()

        let sectionDescriptor = FetchDescriptor<SectionModel>()
        let remainingSections = try context.fetch(sectionDescriptor)
        #expect(remainingSections.isEmpty)
    }

    @Test("cascade delete removes weekly cycles")
    func cascadeDeleteCycles() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let playbook = PlaybookModel(id: "pb-cas-3", title: "Cascade Cycles")
        context.insert(playbook)

        let cycle = WeeklyCycleModel(id: "wc-cas-1", playbookId: "pb-cas-3", weekStartDate: .now)
        cycle.playbook = playbook
        context.insert(cycle)
        try context.save()

        context.delete(playbook)
        try context.save()

        let cycleDescriptor = FetchDescriptor<WeeklyCycleModel>()
        let remainingCycles = try context.fetch(cycleDescriptor)
        #expect(remainingCycles.isEmpty)
    }
}
