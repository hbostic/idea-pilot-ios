//
//  SectionsViewModelTests.swift
//  idea-pilotTests
//
//  Unit tests for SectionsViewModel with mock SectionService.
//

import Foundation
import Testing
@testable import idea_pilot

// MARK: - Mock Section Service

final class MockSectionService: SectionServiceProtocol, @unchecked Sendable {

    nonisolated(unsafe) var fetchResult: Result<[SectionModel], SectionError> = .success([])
    nonisolated(unsafe) var updateResult: Result<SectionModel, SectionError> = .success(
        SectionModel(playbookId: "pb-1", sectionType: .vision, content: "Updated")
    )

    nonisolated(unsafe) var fetchCallCount = 0
    nonisolated(unsafe) var updateCallCount = 0
    nonisolated(unsafe) var capturedUpdatePlaybookId: String?
    nonisolated(unsafe) var capturedUpdateSectionType: SectionType?
    nonisolated(unsafe) var capturedUpdateContent: String?

    nonisolated func fetchSections(playbookId: String, updatedSince: Date?) async throws -> [SectionModel] {
        fetchCallCount += 1
        return try fetchResult.get()
    }

    nonisolated func updateSection(playbookId: String, sectionType: SectionType, content: String) async throws -> SectionModel {
        updateCallCount += 1
        capturedUpdatePlaybookId = playbookId
        capturedUpdateSectionType = sectionType
        capturedUpdateContent = content
        return try updateResult.get()
    }
}

// MARK: - Test Helpers

private func makeSampleSections() -> [SectionModel] {
    [
        SectionModel(playbookId: "pb-1", sectionType: .vision, content: "Our vision is to build great products"),
        SectionModel(playbookId: "pb-1", sectionType: .system, content: "Daily standups"),
        SectionModel(playbookId: "pb-1", sectionType: .build, content: ""),
        SectionModel(playbookId: "pb-1", sectionType: .businessModel, content: "Freemium model"),
    ]
}

private func makePlaybook() -> PlaybookModel {
    PlaybookModel(id: "pb-1", title: "Test Playbook")
}

// MARK: - Tests

@Suite("SectionsViewModel", .serialized)
struct SectionsViewModelTests {

    // MARK: - Load

    @Test("loadSections fetches and populates sections")
    @MainActor func loadSectionsSuccess() async throws {
        let service = MockSectionService()
        service.fetchResult = .success(makeSampleSections())
        let vm = SectionsViewModel(playbook: makePlaybook(), sectionService: service)

        vm.loadSections()
        try await Task.sleep(for: .milliseconds(50))

        #expect(service.fetchCallCount == 1)
        #expect(vm.sections.count == 4)
        #expect(vm.error == nil)
        #expect(vm.isLoading == false)
    }

    @Test("loadSections network error sets error string")
    @MainActor func loadSectionsError() async throws {
        let service = MockSectionService()
        service.fetchResult = .failure(.networkError("timeout"))
        let vm = SectionsViewModel(playbook: makePlaybook(), sectionService: service)

        vm.loadSections()
        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.error == "Network error. Please check your connection.")
        #expect(vm.sections.isEmpty)
        #expect(vm.isLoading == false)
    }

    // MARK: - Ordered Sections

    @Test("orderedSections returns sections in canonical SectionType order")
    @MainActor func orderedSections() {
        let service = MockSectionService()
        let vm = SectionsViewModel(playbook: makePlaybook(), sectionService: service)
        // Insert in reverse order.
        vm.sections = [
            SectionModel(playbookId: "pb-1", sectionType: .businessModel, content: "BM"),
            SectionModel(playbookId: "pb-1", sectionType: .vision, content: "V"),
            SectionModel(playbookId: "pb-1", sectionType: .build, content: "B"),
            SectionModel(playbookId: "pb-1", sectionType: .system, content: "S"),
        ]

        let ordered = vm.orderedSections
        #expect(ordered.count == 4)
        #expect(ordered[0].sectionType == .vision)
        #expect(ordered[1].sectionType == .system)
        #expect(ordered[2].sectionType == .build)
        #expect(ordered[3].sectionType == .businessModel)
    }

    // MARK: - Preview Text

    @Test("previewText returns first line of content")
    @MainActor func previewTextFirstLine() {
        let service = MockSectionService()
        let vm = SectionsViewModel(playbook: makePlaybook(), sectionService: service)
        let section = SectionModel(playbookId: "pb-1", sectionType: .vision, content: "First line\nSecond line\nThird line")

        #expect(vm.previewText(for: section) == "First line")
    }

    @Test("previewText returns placeholder for empty content")
    @MainActor func previewTextEmpty() {
        let service = MockSectionService()
        let vm = SectionsViewModel(playbook: makePlaybook(), sectionService: service)
        let section = SectionModel(playbookId: "pb-1", sectionType: .build, content: "")

        #expect(vm.previewText(for: section) == "No content yet")
    }

    // MARK: - Editor State

    @Test("startEditing sets editingSection and editorContent")
    @MainActor func startEditing() {
        let service = MockSectionService()
        let vm = SectionsViewModel(playbook: makePlaybook(), sectionService: service)
        let section = SectionModel(playbookId: "pb-1", sectionType: .vision, content: "Vision text")

        vm.startEditing(section)

        #expect(vm.editingSection?.compositeId == section.compositeId)
        #expect(vm.editorContent == "Vision text")
    }

    // MARK: - Word and Character Count

    @Test("wordCount and characterCount compute correctly")
    @MainActor func counts() {
        let service = MockSectionService()
        let vm = SectionsViewModel(playbook: makePlaybook(), sectionService: service)

        vm.editorContent = "Hello world foo"
        #expect(vm.wordCount == 3)
        #expect(vm.characterCount == 15)
    }

    @Test("wordCount returns 0 for empty or whitespace-only content")
    @MainActor func countsEmpty() {
        let service = MockSectionService()
        let vm = SectionsViewModel(playbook: makePlaybook(), sectionService: service)

        vm.editorContent = ""
        #expect(vm.wordCount == 0)
        #expect(vm.characterCount == 0)

        vm.editorContent = "   \n  "
        #expect(vm.wordCount == 0)
    }

    // MARK: - Debounced Save

    @Test("saveContent updates model immediately but debounces API call")
    @MainActor func saveContentDebounce() async throws {
        let service = MockSectionService()
        let vm = SectionsViewModel(playbook: makePlaybook(), sectionService: service)
        let section = SectionModel(playbookId: "pb-1", sectionType: .vision, content: "Old")
        vm.sections = [section]
        vm.startEditing(section)

        vm.editorContent = "New content"
        vm.saveContent()

        // Model updated immediately.
        #expect(section.content == "New content")

        // API not called yet.
        try await Task.sleep(for: .milliseconds(50))
        #expect(service.updateCallCount == 0)

        // Wait for debounce.
        try await Task.sleep(for: .milliseconds(1100))
        #expect(service.updateCallCount == 1)
        #expect(service.capturedUpdateContent == "New content")
        #expect(service.capturedUpdateSectionType == .vision)
    }

    @Test("saveContent cancels previous debounce on rapid changes")
    @MainActor func saveContentCancelsPrevious() async throws {
        let service = MockSectionService()
        let vm = SectionsViewModel(playbook: makePlaybook(), sectionService: service)
        let section = SectionModel(playbookId: "pb-1", sectionType: .vision, content: "Old")
        vm.sections = [section]
        vm.startEditing(section)

        vm.editorContent = "First"
        vm.saveContent()
        try await Task.sleep(for: .milliseconds(500))

        vm.editorContent = "Second"
        vm.saveContent()
        try await Task.sleep(for: .milliseconds(500))

        // Only 500ms since last call, no API calls yet.
        #expect(service.updateCallCount == 0)

        // Wait for second debounce to complete.
        try await Task.sleep(for: .milliseconds(700))
        #expect(service.updateCallCount == 1)
        #expect(service.capturedUpdateContent == "Second")
    }

    // MARK: - Save Error

    @Test("saveContent error sets error string after debounce")
    @MainActor func saveContentError() async throws {
        let service = MockSectionService()
        service.updateResult = .failure(.serverError("Server error"))
        let vm = SectionsViewModel(playbook: makePlaybook(), sectionService: service)
        let section = SectionModel(playbookId: "pb-1", sectionType: .vision, content: "Old")
        vm.sections = [section]
        vm.startEditing(section)

        vm.editorContent = "New content"
        vm.saveContent()

        try await Task.sleep(for: .milliseconds(1200))
        #expect(vm.error != nil)
    }

    // MARK: - Refresh

    @Test("refresh calls fetch and updates list")
    @MainActor func refreshSuccess() async throws {
        let service = MockSectionService()
        service.fetchResult = .success(makeSampleSections())
        let vm = SectionsViewModel(playbook: makePlaybook(), sectionService: service)

        await vm.refresh()

        #expect(service.fetchCallCount == 1)
        #expect(vm.sections.count == 4)
        #expect(vm.error == nil)
    }
}
