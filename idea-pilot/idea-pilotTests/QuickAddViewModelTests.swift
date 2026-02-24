//
//  QuickAddViewModelTests.swift
//  idea-pilotTests
//
//  Unit tests for QuickAddViewModel — form state, validation, submission, and reset.
//

import Foundation
import Testing
@testable import idea_pilot

@Suite("QuickAddViewModel", .serialized)
struct QuickAddViewModelTests {

    // MARK: - Default State

    @Test("default state has empty title, LATER lane, 60m estimate, nil playbook")
    @MainActor func defaultState() {
        let vm = QuickAddViewModel(
            taskService: MockTaskService(),
            playbookService: MockPlaybookService()
        )

        #expect(vm.title == "")
        #expect(vm.selectedLane == .later)
        #expect(vm.estimatedMinutes == 60)
        #expect(vm.selectedPlaybook == nil)
        #expect(vm.isTitleValid == false)
        #expect(vm.canSubmit == false)
        #expect(vm.showSuccessFlash == false)
        #expect(vm.isSubmitting == false)
        #expect(vm.error == nil)
    }

    // MARK: - Validation

    @Test("isTitleValid returns false for empty and whitespace-only titles")
    @MainActor func titleValidation() {
        let vm = QuickAddViewModel(
            taskService: MockTaskService(),
            playbookService: MockPlaybookService()
        )

        vm.title = ""
        #expect(vm.isTitleValid == false)

        vm.title = "   "
        #expect(vm.isTitleValid == false)

        vm.title = "\n\t"
        #expect(vm.isTitleValid == false)

        vm.title = "Buy groceries"
        #expect(vm.isTitleValid == true)
    }

    @Test("canSubmit requires valid title and selected playbook")
    @MainActor func canSubmitValidation() {
        let vm = QuickAddViewModel(
            taskService: MockTaskService(),
            playbookService: MockPlaybookService()
        )

        // No title, no playbook.
        #expect(vm.canSubmit == false)

        // Title only, no playbook.
        vm.title = "Do something"
        #expect(vm.canSubmit == false)

        // Playbook only, no title.
        vm.title = ""
        vm.selectedPlaybook = PlaybookModel(id: "pb-1", title: "Test")
        #expect(vm.canSubmit == false)

        // Both present.
        vm.title = "Do something"
        #expect(vm.canSubmit == true)
    }

    @Test("addButtonTitle includes selected lane name")
    @MainActor func addButtonTitle() {
        let vm = QuickAddViewModel(
            taskService: MockTaskService(),
            playbookService: MockPlaybookService()
        )

        vm.selectedLane = .now
        #expect(vm.addButtonTitle == "Add to NOW")

        vm.selectedLane = .next
        #expect(vm.addButtonTitle == "Add to NEXT")

        vm.selectedLane = .later
        #expect(vm.addButtonTitle == "Add to LATER")
    }

    // MARK: - Load Playbooks

    @Test("loadPlaybooks fetches and selects first playbook")
    @MainActor func loadPlaybooksSelectsFirst() async throws {
        let mockPlaybookService = MockPlaybookService()
        let playbooks = [
            PlaybookModel(id: "pb-1", title: "Active One"),
            PlaybookModel(id: "pb-2", title: "Active Two"),
        ]
        mockPlaybookService.fetchResult = .success(playbooks)

        let vm = QuickAddViewModel(
            taskService: MockTaskService(),
            playbookService: mockPlaybookService
        )

        vm.loadPlaybooks()
        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.playbooks.count == 2)
        #expect(vm.selectedPlaybook?.id == "pb-1")
    }

    @Test("loadPlaybooks filters out archived playbooks")
    @MainActor func loadPlaybooksFiltersArchived() async throws {
        let mockPlaybookService = MockPlaybookService()
        let active = PlaybookModel(id: "pb-1", title: "Active")
        let archived = PlaybookModel(id: "pb-2", title: "Archived", isArchived: true)
        mockPlaybookService.fetchResult = .success([archived, active])

        let vm = QuickAddViewModel(
            taskService: MockTaskService(),
            playbookService: mockPlaybookService
        )

        vm.loadPlaybooks()
        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.playbooks.count == 1)
        #expect(vm.selectedPlaybook?.id == "pb-1")
    }

    // MARK: - Add Task

    @Test("addTask calls service with correct parameters")
    @MainActor func addTaskCallsService() async throws {
        let mockTaskService = MockTaskService()
        let task = TaskModel(playbookId: "pb-1", title: "New Task", lane: .now, estimatedMinutes: 90)
        mockTaskService.createResult = .success(task)

        let vm = QuickAddViewModel(
            taskService: mockTaskService,
            playbookService: MockPlaybookService()
        )
        vm.selectedPlaybook = PlaybookModel(id: "pb-1", title: "Test")
        vm.title = "New Task"
        vm.selectedLane = .now
        vm.estimatedMinutes = 90

        vm.addTask()
        try await Task.sleep(for: .milliseconds(50))

        #expect(mockTaskService.createCallCount == 1)
        #expect(mockTaskService.capturedCreatePlaybookId == "pb-1")
        #expect(mockTaskService.capturedCreateTitle == "New Task")
        #expect(mockTaskService.capturedCreateLane == .now)
        #expect(mockTaskService.capturedCreateEstimate == 90)
        #expect(vm.error == nil)
    }

    @Test("addTask clears title but preserves playbook selection on success")
    @MainActor func addTaskClearsFormOnSuccess() async throws {
        let mockTaskService = MockTaskService()
        let task = TaskModel(playbookId: "pb-1", title: "New Task")
        mockTaskService.createResult = .success(task)

        let vm = QuickAddViewModel(
            taskService: mockTaskService,
            playbookService: MockPlaybookService()
        )
        let playbook = PlaybookModel(id: "pb-1", title: "Test")
        vm.selectedPlaybook = playbook
        vm.title = "New Task"
        vm.selectedLane = .now
        vm.estimatedMinutes = 90

        vm.addTask()
        try await Task.sleep(for: .milliseconds(50))

        // Form fields reset to defaults.
        #expect(vm.title == "")
        #expect(vm.selectedLane == .later)
        #expect(vm.estimatedMinutes == 60)

        // Playbook preserved.
        #expect(vm.selectedPlaybook?.id == "pb-1")

        // Success flash triggered.
        #expect(vm.showSuccessFlash == true)
    }

    @Test("addTask success flash auto-dismisses after delay")
    @MainActor func addTaskSuccessFlashAutoDismisses() async throws {
        let mockTaskService = MockTaskService()
        mockTaskService.createResult = .success(TaskModel(playbookId: "pb-1", title: "Task"))

        let vm = QuickAddViewModel(
            taskService: mockTaskService,
            playbookService: MockPlaybookService()
        )
        vm.selectedPlaybook = PlaybookModel(id: "pb-1", title: "Test")
        vm.title = "Task"

        vm.addTask()
        try await Task.sleep(for: .milliseconds(50))
        #expect(vm.showSuccessFlash == true)

        // Wait for flash to auto-dismiss.
        try await Task.sleep(for: .milliseconds(1000))
        #expect(vm.showSuccessFlash == false)
    }

    @Test("addTask with empty title does not call service")
    @MainActor func addTaskEmptyTitleNoOp() async throws {
        let mockTaskService = MockTaskService()
        let vm = QuickAddViewModel(
            taskService: mockTaskService,
            playbookService: MockPlaybookService()
        )
        vm.selectedPlaybook = PlaybookModel(id: "pb-1", title: "Test")
        vm.title = "   "

        vm.addTask()
        try await Task.sleep(for: .milliseconds(50))

        #expect(mockTaskService.createCallCount == 0)
        #expect(vm.showSuccessFlash == false)
    }

    @Test("addTask error sets error string and preserves form")
    @MainActor func addTaskError() async throws {
        let mockTaskService = MockTaskService()
        mockTaskService.createResult = .failure(.serverError("Server error"))

        let vm = QuickAddViewModel(
            taskService: mockTaskService,
            playbookService: MockPlaybookService()
        )
        vm.selectedPlaybook = PlaybookModel(id: "pb-1", title: "Test")
        vm.title = "Task"
        vm.selectedLane = .now
        vm.estimatedMinutes = 90

        vm.addTask()
        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.error != nil)
        // Title preserved on error.
        #expect(vm.title == "Task")
        #expect(vm.selectedLane == .now)
        #expect(vm.estimatedMinutes == 90)
    }

    @Test("addTask with no selected playbook does not call service")
    @MainActor func addTaskNoPlaybookNoOp() async throws {
        let mockTaskService = MockTaskService()
        let vm = QuickAddViewModel(
            taskService: mockTaskService,
            playbookService: MockPlaybookService()
        )
        vm.title = "Task"
        vm.selectedPlaybook = nil

        vm.addTask()
        try await Task.sleep(for: .milliseconds(50))

        #expect(mockTaskService.createCallCount == 0)
        #expect(vm.showSuccessFlash == false)
    }

    // MARK: - Discard State

    @Test("hasUnsavedContent returns true when title is non-empty")
    @MainActor func hasUnsavedContent() {
        let vm = QuickAddViewModel(
            taskService: MockTaskService(),
            playbookService: MockPlaybookService()
        )

        #expect(vm.hasUnsavedContent == false)

        vm.title = "Something"
        #expect(vm.hasUnsavedContent == true)

        vm.title = "   "
        #expect(vm.hasUnsavedContent == false)
    }

    // MARK: - Clear Form

    @Test("clearForm resets all fields to defaults")
    @MainActor func clearFormResetsAll() {
        let vm = QuickAddViewModel(
            taskService: MockTaskService(),
            playbookService: MockPlaybookService()
        )
        vm.title = "Task"
        vm.selectedLane = .now
        vm.estimatedMinutes = 120
        vm.error = "Some error"

        vm.clearForm()

        #expect(vm.title == "")
        #expect(vm.selectedLane == .later)
        #expect(vm.estimatedMinutes == 60)
        #expect(vm.error == nil)
    }
}
