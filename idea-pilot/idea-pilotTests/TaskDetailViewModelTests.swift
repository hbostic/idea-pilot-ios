//
//  TaskDetailViewModelTests.swift
//  idea-pilotTests
//
//  Unit tests for TaskDetailViewModel — editing, saving, completing, and deleting tasks.
//

import Foundation
import Testing
@testable import idea_pilot

@Suite("TaskDetailViewModel", .serialized)
struct TaskDetailViewModelTests {

    // MARK: - Helpers

    private func makeTask(
        id: String = "t-1",
        title: String = "Test Task",
        detail: String? = "Some notes",
        lane: TaskLane = .now,
        estimatedMinutes: Int = 60,
        status: TaskStatus = .open
    ) -> TaskModel {
        TaskModel(
            id: id,
            playbookId: "pb-1",
            title: title,
            detail: detail,
            lane: lane,
            estimatedMinutes: estimatedMinutes,
            status: status,
            orderIndex: 0
        )
    }

    private func makeVM(
        task: TaskModel? = nil,
        mockService: MockTaskService? = nil,
        onComplete: @escaping (String) -> Void = { _ in },
        onDelete: @escaping (String) -> Void = { _ in }
    ) -> (TaskDetailViewModel, MockTaskService) {
        let service = mockService ?? MockTaskService()
        let t = task ?? makeTask()
        let vm = TaskDetailViewModel(
            task: t,
            taskService: service,
            onComplete: onComplete,
            onDelete: onDelete
        )
        return (vm, service)
    }

    // MARK: - Default State

    @Test("initializes from task properties")
    @MainActor func defaultState() {
        let task = makeTask(title: "My Task", detail: "Notes here", lane: .next, estimatedMinutes: 90)
        let (vm, _) = makeVM(task: task)

        #expect(vm.title == "My Task")
        #expect(vm.detail == "Notes here")
        #expect(vm.selectedLane == .next)
        #expect(vm.estimatedMinutes == 90)
        #expect(vm.isOpen == true)
        #expect(vm.statusLabel == "OPEN")
        #expect(vm.showEstimateWarning == false)
        #expect(vm.isSubmitting == false)
        #expect(vm.error == nil)
    }

    @Test("initializes with empty string when task detail is nil")
    @MainActor func defaultStateNilDetail() {
        let task = makeTask(detail: nil)
        let (vm, _) = makeVM(task: task)

        #expect(vm.detail == "")
    }

    // MARK: - Status

    @Test("statusLabel returns DONE for completed tasks")
    @MainActor func statusLabelDone() {
        let task = makeTask(status: .done)
        let (vm, _) = makeVM(task: task)

        #expect(vm.statusLabel == "DONE")
        #expect(vm.isOpen == false)
    }

    // MARK: - Save Title

    @Test("saveTitle updates task and calls service")
    @MainActor func saveTitleSuccess() async throws {
        let task = makeTask()
        let (vm, service) = makeVM(task: task)
        service.updateResult = .success(task)

        vm.title = "Updated Title"
        vm.saveTitle()
        try await Task.sleep(for: .milliseconds(50))

        #expect(task.title == "Updated Title")
        #expect(service.updateCallCount == 1)
        #expect(service.capturedUpdateDTO?.title == "Updated Title")
        #expect(vm.error == nil)
    }

    @Test("saveTitle with empty string reverts to task title")
    @MainActor func saveTitleEmptyReverts() {
        let task = makeTask(title: "Original")
        let (vm, service) = makeVM(task: task)

        vm.title = "   "
        vm.saveTitle()

        #expect(vm.title == "Original")
        #expect(task.title == "Original")
        #expect(service.updateCallCount == 0)
    }

    @Test("saveTitle trims whitespace")
    @MainActor func saveTitleTrimsWhitespace() async throws {
        let task = makeTask()
        let (vm, service) = makeVM(task: task)
        service.updateResult = .success(task)

        vm.title = "  Trimmed  "
        vm.saveTitle()
        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.title == "Trimmed")
        #expect(task.title == "Trimmed")
    }

    // MARK: - Save Lane

    @Test("saveLane updates task and calls service")
    @MainActor func saveLaneSuccess() async throws {
        let task = makeTask(lane: .now)
        let (vm, service) = makeVM(task: task)
        service.updateResult = .success(task)

        vm.saveLane(.later)
        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.selectedLane == .later)
        #expect(task.lane == .later)
        #expect(service.updateCallCount == 1)
        #expect(service.capturedUpdateDTO?.lane == "LATER")
    }

    // MARK: - Save Estimate

    @Test("saveEstimate updates task and calls service")
    @MainActor func saveEstimateSuccess() async throws {
        let task = makeTask(estimatedMinutes: 60)
        let (vm, service) = makeVM(task: task)
        service.updateResult = .success(task)

        vm.saveEstimate(120)
        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.estimatedMinutes == 120)
        #expect(task.estimatedMinutes == 120)
        #expect(service.updateCallCount == 1)
    }

    @Test("showEstimateWarning is true when estimate exceeds 180")
    @MainActor func estimateWarning() {
        let task = makeTask(estimatedMinutes: 60)
        let (vm, _) = makeVM(task: task)

        #expect(vm.showEstimateWarning == false)

        vm.estimatedMinutes = 181
        #expect(vm.showEstimateWarning == true)

        vm.estimatedMinutes = 180
        #expect(vm.showEstimateWarning == false)
    }

    // MARK: - Save Detail (Debounced)

    @Test("saveDetail updates task model immediately but debounces API call")
    @MainActor func saveDetailDebounce() async throws {
        let task = makeTask(detail: nil)
        let (vm, service) = makeVM(task: task)
        service.updateResult = .success(task)

        vm.detail = "New notes"
        vm.saveDetail()

        // Task model updated immediately.
        #expect(task.detail == "New notes")

        // API not called yet (debounce).
        try await Task.sleep(for: .milliseconds(50))
        #expect(service.updateCallCount == 0)

        // Wait for debounce to complete.
        try await Task.sleep(for: .milliseconds(1100))
        #expect(service.updateCallCount == 1)
    }

    @Test("saveDetail cancels previous debounce on rapid changes")
    @MainActor func saveDetailCancelsPrevious() async throws {
        let task = makeTask()
        let (vm, service) = makeVM(task: task)
        service.updateResult = .success(task)

        vm.detail = "First"
        vm.saveDetail()
        try await Task.sleep(for: .milliseconds(500))

        vm.detail = "Second"
        vm.saveDetail()
        try await Task.sleep(for: .milliseconds(500))

        // Only 500ms since last call, so no API calls yet.
        #expect(service.updateCallCount == 0)

        // Wait for second debounce to complete.
        try await Task.sleep(for: .milliseconds(700))
        #expect(service.updateCallCount == 1)
    }

    // MARK: - Complete Task

    @Test("completeTask sets done status and calls onComplete")
    @MainActor func completeTaskSuccess() async throws {
        let task = makeTask()
        let completedTask = TaskModel(id: "t-1", playbookId: "pb-1", title: "Test Task", status: .done, completedAt: .now)
        var completedId: String?

        let service = MockTaskService()
        service.completeResult = .success(completedTask)

        let vm = TaskDetailViewModel(
            task: task,
            taskService: service,
            onComplete: { completedId = $0 },
            onDelete: { _ in }
        )

        vm.completeTask()
        try await Task.sleep(for: .milliseconds(50))

        #expect(task.status == .done)
        #expect(task.completedAt != nil)
        #expect(service.completeCallCount == 1)
        #expect(completedId == "t-1")
    }

    @Test("completeTask rolls back on error")
    @MainActor func completeTaskRollback() async throws {
        let task = makeTask()
        let service = MockTaskService()
        service.completeResult = .failure(.serverError("Server error"))

        let (vm, _) = makeVM(task: task, mockService: service)

        vm.completeTask()
        try await Task.sleep(for: .milliseconds(50))

        #expect(task.status == .open)
        #expect(task.completedAt == nil)
        #expect(vm.error != nil)
    }

    @Test("completeTask does nothing when task is already done")
    @MainActor func completeTaskAlreadyDone() async throws {
        let task = makeTask(status: .done)
        let (vm, service) = makeVM(task: task)

        vm.completeTask()
        try await Task.sleep(for: .milliseconds(50))

        #expect(service.completeCallCount == 0)
    }

    // MARK: - Delete Task

    @Test("deleteTask calls service and onDelete callback")
    @MainActor func deleteTaskSuccess() async throws {
        var deletedId: String?
        let service = MockTaskService()

        let vm = TaskDetailViewModel(
            task: makeTask(),
            taskService: service,
            onComplete: { _ in },
            onDelete: { deletedId = $0 }
        )

        vm.deleteTask()
        try await Task.sleep(for: .milliseconds(50))

        #expect(service.deleteCallCount == 1)
        #expect(deletedId == "t-1")
    }

    @Test("deleteTask error sets error string")
    @MainActor func deleteTaskError() async throws {
        let service = MockTaskService()
        service.deleteResult = .failure(.serverError("Server error"))

        let (vm, _) = makeVM(mockService: service)

        vm.deleteTask()
        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.error != nil)
        #expect(vm.isSubmitting == false)
    }
}
