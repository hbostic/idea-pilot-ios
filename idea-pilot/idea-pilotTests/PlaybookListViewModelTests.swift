//
//  PlaybookListViewModelTests.swift
//  idea-pilotTests
//
//  Unit tests for PlaybookListViewModel with mock PlaybookService.
//

import Foundation
import Testing
@testable import idea_pilot

// MARK: - Mock Playbook Service

/// Mock implementation of `PlaybookServiceProtocol` for ViewModel testing.
final class MockPlaybookService: PlaybookServiceProtocol, @unchecked Sendable {

    nonisolated(unsafe) var fetchResult: Result<[PlaybookModel], PlaybookError> = .success([])
    nonisolated(unsafe) var createResult: Result<PlaybookModel, PlaybookError> = .success(
        PlaybookModel(id: "pb-new", title: "New Playbook")
    )
    nonisolated(unsafe) var archiveResult: Result<Void, PlaybookError> = .success(())

    nonisolated(unsafe) var fetchCallCount = 0
    nonisolated(unsafe) var createCallCount = 0
    nonisolated(unsafe) var archiveCallCount = 0

    nonisolated(unsafe) var capturedTitle: String?
    nonisolated(unsafe) var capturedDescription: String?
    nonisolated(unsafe) var capturedArchiveId: String?

    nonisolated func fetchPlaybooks(updatedSince: Date?) async throws -> [PlaybookModel] {
        fetchCallCount += 1
        return try fetchResult.get()
    }

    nonisolated func createPlaybook(title: String, description: String?) async throws -> PlaybookModel {
        createCallCount += 1
        capturedTitle = title
        capturedDescription = description
        return try createResult.get()
    }

    nonisolated func archivePlaybook(id: String) async throws {
        archiveCallCount += 1
        capturedArchiveId = id
        try archiveResult.get()
    }
}

// MARK: - Test Helpers

private func makeSamplePlaybooks() -> [PlaybookModel] {
    [
        PlaybookModel(id: "pb-1", title: "Playbook One"),
        PlaybookModel(id: "pb-2", title: "Playbook Two"),
    ]
}

private func makeMixedPlaybooks() -> [PlaybookModel] {
    let active = PlaybookModel(id: "pb-1", title: "Active Playbook")
    let archived = PlaybookModel(id: "pb-2", title: "Archived Playbook", isArchived: true)
    return [active, archived]
}

// MARK: - PlaybookListViewModel Tests

@Suite("PlaybookListViewModel", .serialized)
struct PlaybookListViewModelTests {

    // MARK: - Load

    @Test("loadPlaybooks fetches and populates playbooks array")
    @MainActor func loadPlaybooksSuccess() async throws {
        let mockService = MockPlaybookService()
        mockService.fetchResult = .success(makeSamplePlaybooks())
        let vm = PlaybookListViewModel(playbookService: mockService)

        vm.loadPlaybooks()
        try await Task.sleep(for: .milliseconds(50))

        #expect(mockService.fetchCallCount == 1)
        #expect(vm.playbooks.count == 2)
        #expect(vm.error == nil)
        #expect(vm.isLoading == false)
    }

    @Test("loadPlaybooks sets isLoading during fetch")
    @MainActor func loadPlaybooksSetsLoading() async throws {
        let mockService = MockPlaybookService()
        let vm = PlaybookListViewModel(playbookService: mockService)

        vm.loadPlaybooks()

        #expect(vm.isLoading == true)

        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.isLoading == false)
    }

    @Test("loadPlaybooks network error sets error string")
    @MainActor func loadPlaybooksNetworkError() async throws {
        let mockService = MockPlaybookService()
        mockService.fetchResult = .failure(.networkError("timeout"))
        let vm = PlaybookListViewModel(playbookService: mockService)

        vm.loadPlaybooks()
        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.error == "Network error. Please check your connection.")
        #expect(vm.playbooks.isEmpty)
        #expect(vm.isLoading == false)
    }

    // MARK: - Refresh

    @Test("refresh calls fetch and updates list")
    @MainActor func refreshCallsFetch() async throws {
        let mockService = MockPlaybookService()
        mockService.fetchResult = .success(makeSamplePlaybooks())
        let vm = PlaybookListViewModel(playbookService: mockService)

        await vm.refresh()

        #expect(mockService.fetchCallCount == 1)
        #expect(vm.playbooks.count == 2)
        #expect(vm.error == nil)
    }

    // MARK: - Create

    @Test("createPlaybook validates, calls service, appends to list, clears state")
    @MainActor func createPlaybookSuccess() async throws {
        let mockService = MockPlaybookService()
        let newPlaybook = PlaybookModel(id: "pb-new", title: "My Idea")
        mockService.createResult = .success(newPlaybook)
        let vm = PlaybookListViewModel(playbookService: mockService)
        vm.newPlaybookTitle = "My Idea"
        vm.showCreateSheet = true

        vm.createPlaybook()
        try await Task.sleep(for: .milliseconds(50))

        #expect(mockService.createCallCount == 1)
        #expect(mockService.capturedTitle == "My Idea")
        #expect(vm.playbooks.count == 1)
        #expect(vm.playbooks.first?.title == "My Idea")
        #expect(vm.newPlaybookTitle == "")
        #expect(vm.showCreateSheet == false)
        #expect(vm.error == nil)
    }

    @Test("createPlaybook with empty title does not call service")
    @MainActor func createPlaybookEmptyTitle() async throws {
        let mockService = MockPlaybookService()
        let vm = PlaybookListViewModel(playbookService: mockService)
        vm.newPlaybookTitle = "   "

        vm.createPlaybook()
        try await Task.sleep(for: .milliseconds(50))

        #expect(mockService.createCallCount == 0)
    }

    // MARK: - Archive

    @Test("archivePlaybook calls service and marks playbook archived")
    @MainActor func archivePlaybookSuccess() async throws {
        let mockService = MockPlaybookService()
        let vm = PlaybookListViewModel(playbookService: mockService)
        vm.playbooks = makeSamplePlaybooks()

        vm.archivePlaybook(id: "pb-1")
        try await Task.sleep(for: .milliseconds(50))

        #expect(mockService.archiveCallCount == 1)
        #expect(mockService.capturedArchiveId == "pb-1")
        #expect(vm.playbooks.first(where: { $0.id == "pb-1" })?.isArchived == true)
        #expect(vm.error == nil)
    }

    @Test("archivePlaybook error sets error string")
    @MainActor func archivePlaybookError() async throws {
        let mockService = MockPlaybookService()
        mockService.archiveResult = .failure(.serverError("Server error"))
        let vm = PlaybookListViewModel(playbookService: mockService)
        vm.playbooks = makeSamplePlaybooks()

        vm.archivePlaybook(id: "pb-1")
        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.error == "Something went wrong. Please try again.")
    }

    // MARK: - Filtering

    @Test("filteredPlaybooks hides archived by default")
    @MainActor func filteredPlaybooksHidesArchived() {
        let mockService = MockPlaybookService()
        let vm = PlaybookListViewModel(playbookService: mockService)
        vm.playbooks = makeMixedPlaybooks()

        #expect(vm.filteredPlaybooks.count == 1)
        #expect(vm.filteredPlaybooks.first?.id == "pb-1")
    }

    @Test("toggleShowArchived reveals archived playbooks")
    @MainActor func toggleShowArchivedReveals() {
        let mockService = MockPlaybookService()
        let vm = PlaybookListViewModel(playbookService: mockService)
        vm.playbooks = makeMixedPlaybooks()

        vm.toggleShowArchived()

        #expect(vm.showArchived == true)
        #expect(vm.filteredPlaybooks.count == 2)
    }
}
