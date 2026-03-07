//
//  NowTabViewModelTests.swift
//  idea-pilotTests
//
//  Unit tests for NowTabViewModel — last-viewed playbook resolution,
//  persistence, empty state, and create flow.
//

import Foundation
import Testing
@testable import idea_pilot

// MARK: - NowTabViewModel Tests

@Suite("NowTabViewModel", .serialized)
struct NowTabViewModelTests {

    // Clean up UserDefaults before each test.
    init() {
        UserDefaults.standard.removeObject(forKey: NowTabViewModel.lastViewedPlaybookKey)
    }

    // MARK: - Load / Resolution

    @Test("loadPlaybook resolves first playbook when no last-viewed is stored")
    @MainActor func loadResolvesFirstPlaybook() async throws {
        let mockService = MockPlaybookService()
        mockService.fetchResult = .success([
            PlaybookModel(id: "pb-1", title: "First"),
            PlaybookModel(id: "pb-2", title: "Second"),
        ])
        let vm = NowTabViewModel(playbookService: mockService)

        vm.loadPlaybook()
        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.playbook?.id == "pb-1")
        #expect(NowTabViewModel.lastViewedPlaybookId() == "pb-1")
    }

    @Test("loadPlaybook resolves last-viewed playbook from UserDefaults")
    @MainActor func loadResolvesLastViewed() async throws {
        NowTabViewModel.saveLastViewedPlaybookId("pb-2")

        let mockService = MockPlaybookService()
        mockService.fetchResult = .success([
            PlaybookModel(id: "pb-1", title: "First"),
            PlaybookModel(id: "pb-2", title: "Second"),
        ])
        let vm = NowTabViewModel(playbookService: mockService)

        vm.loadPlaybook()
        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.playbook?.id == "pb-2")
    }

    @Test("loadPlaybook falls back to first when last-viewed no longer exists")
    @MainActor func loadFallsBackWhenLastViewedDeleted() async throws {
        NowTabViewModel.saveLastViewedPlaybookId("pb-deleted")

        let mockService = MockPlaybookService()
        mockService.fetchResult = .success([
            PlaybookModel(id: "pb-1", title: "First"),
        ])
        let vm = NowTabViewModel(playbookService: mockService)

        vm.loadPlaybook()
        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.playbook?.id == "pb-1")
        #expect(NowTabViewModel.lastViewedPlaybookId() == "pb-1")
    }

    @Test("loadPlaybook skips archived playbooks")
    @MainActor func loadSkipsArchived() async throws {
        let mockService = MockPlaybookService()
        mockService.fetchResult = .success([
            PlaybookModel(id: "pb-archived", title: "Archived", isArchived: true),
            PlaybookModel(id: "pb-active", title: "Active"),
        ])
        let vm = NowTabViewModel(playbookService: mockService)

        vm.loadPlaybook()
        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.playbook?.id == "pb-active")
    }

    @Test("loadPlaybook falls back to first when last-viewed is archived")
    @MainActor func loadFallsBackWhenLastViewedArchived() async throws {
        NowTabViewModel.saveLastViewedPlaybookId("pb-archived")

        let mockService = MockPlaybookService()
        mockService.fetchResult = .success([
            PlaybookModel(id: "pb-archived", title: "Archived", isArchived: true),
            PlaybookModel(id: "pb-active", title: "Active"),
        ])
        let vm = NowTabViewModel(playbookService: mockService)

        vm.loadPlaybook()
        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.playbook?.id == "pb-active")
    }

    // MARK: - Empty State

    @Test("loadPlaybook sets nil playbook when no playbooks exist")
    @MainActor func loadEmptyState() async throws {
        let mockService = MockPlaybookService()
        mockService.fetchResult = .success([])
        let vm = NowTabViewModel(playbookService: mockService)

        vm.loadPlaybook()
        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.playbook == nil)
        #expect(vm.error == nil)
    }

    @Test("loadPlaybook sets nil playbook when all are archived")
    @MainActor func loadAllArchived() async throws {
        let mockService = MockPlaybookService()
        mockService.fetchResult = .success([
            PlaybookModel(id: "pb-1", title: "Archived", isArchived: true),
        ])
        let vm = NowTabViewModel(playbookService: mockService)

        vm.loadPlaybook()
        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.playbook == nil)
    }

    // MARK: - Error Handling

    @Test("loadPlaybook sets error on service failure")
    @MainActor func loadError() async throws {
        let mockService = MockPlaybookService()
        mockService.fetchResult = .failure(.networkError("connection failed"))
        let vm = NowTabViewModel(playbookService: mockService)

        vm.loadPlaybook()
        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.error != nil)
        #expect(vm.playbook == nil)
    }

    // MARK: - Refresh

    @Test("refresh reloads and resolves playbooks")
    @MainActor func refreshSuccess() async throws {
        let mockService = MockPlaybookService()
        mockService.fetchResult = .success([
            PlaybookModel(id: "pb-1", title: "First"),
        ])
        let vm = NowTabViewModel(playbookService: mockService)

        await vm.refresh()

        #expect(vm.playbook?.id == "pb-1")
        #expect(mockService.fetchCallCount == 1)
    }

    // MARK: - Create Playbook

    @Test("createPlaybook creates and sets as active playbook")
    @MainActor func createSuccess() async throws {
        let mockService = MockPlaybookService()
        let created = PlaybookModel(id: "pb-new", title: "New Playbook")
        mockService.createResult = .success(created)
        let vm = NowTabViewModel(playbookService: mockService)

        vm.newPlaybookTitle = "New Playbook"
        vm.newPlaybookDescription = "Description"
        vm.showCreateSheet = true
        vm.createPlaybook()
        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.playbook?.id == "pb-new")
        #expect(vm.showCreateSheet == false)
        #expect(vm.newPlaybookTitle == "")
        #expect(vm.newPlaybookDescription == "")
        #expect(NowTabViewModel.lastViewedPlaybookId() == "pb-new")
    }

    @Test("createPlaybook does nothing with empty title")
    @MainActor func createEmptyTitle() async throws {
        let mockService = MockPlaybookService()
        let vm = NowTabViewModel(playbookService: mockService)

        vm.newPlaybookTitle = "   "
        vm.createPlaybook()
        try await Task.sleep(for: .milliseconds(50))

        #expect(mockService.createCallCount == 0)
    }

    // MARK: - Persistence

    @Test("saveLastViewedPlaybookId and lastViewedPlaybookId round-trip")
    func persistenceRoundTrip() {
        NowTabViewModel.saveLastViewedPlaybookId("pb-123")
        #expect(NowTabViewModel.lastViewedPlaybookId() == "pb-123")
    }

    @Test("lastViewedPlaybookId returns nil when nothing is stored")
    func persistenceNil() {
        #expect(NowTabViewModel.lastViewedPlaybookId() == nil)
    }
}
