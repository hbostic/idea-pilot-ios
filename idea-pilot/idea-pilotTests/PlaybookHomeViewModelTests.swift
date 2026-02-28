//
//  PlaybookHomeViewModelTests.swift
//  idea-pilotTests
//
//  Unit tests for PlaybookHomeViewModel with mock TaskService.
//

import Foundation
import SwiftData
import Testing
@testable import idea_pilot

// MARK: - Mock Task Service

/// Mock implementation of `TaskServiceProtocol` for ViewModel testing.
final class MockTaskService: TaskServiceProtocol, @unchecked Sendable {

    nonisolated(unsafe) var fetchResult: Result<[TaskModel], TaskError> = .success([])
    nonisolated(unsafe) var createResult: Result<TaskModel, TaskError> = .success(
        TaskModel(playbookId: "pb-1", title: "New Task")
    )
    nonisolated(unsafe) var updateResult: Result<TaskModel, TaskError> = .success(
        TaskModel(playbookId: "pb-1", title: "Updated Task")
    )
    nonisolated(unsafe) var completeResult: Result<TaskModel, TaskError> = .success(
        TaskModel(playbookId: "pb-1", title: "Done Task", status: .done)
    )
    nonisolated(unsafe) var reorderResult: Result<Void, TaskError> = .success(())
    nonisolated(unsafe) var deleteResult: Result<Void, TaskError> = .success(())

    nonisolated(unsafe) var fetchCallCount = 0
    nonisolated(unsafe) var completeCallCount = 0
    nonisolated(unsafe) var updateCallCount = 0
    nonisolated(unsafe) var reorderCallCount = 0
    nonisolated(unsafe) var createCallCount = 0
    nonisolated(unsafe) var deleteCallCount = 0

    nonisolated(unsafe) var capturedCreatePlaybookId: String?
    nonisolated(unsafe) var capturedCreateTitle: String?
    nonisolated(unsafe) var capturedCreateLane: TaskLane?
    nonisolated(unsafe) var capturedCreateEstimate: Int?
    nonisolated(unsafe) var capturedCompleteId: String?
    nonisolated(unsafe) var capturedUpdateId: String?
    nonisolated(unsafe) var capturedUpdateDTO: UpdateTaskDTO?
    nonisolated(unsafe) var capturedReorderTaskIds: [String]?
    nonisolated(unsafe) var capturedReorderLane: TaskLane?

    nonisolated func fetchTasks(playbookId: String, lane: TaskLane?, updatedSince: Date?) async throws -> [TaskModel] {
        fetchCallCount += 1
        return try fetchResult.get()
    }

    nonisolated func createTask(playbookId: String, title: String, detail: String?, lane: TaskLane, estimatedMinutes: Int) async throws -> TaskModel {
        createCallCount += 1
        capturedCreatePlaybookId = playbookId
        capturedCreateTitle = title
        capturedCreateLane = lane
        capturedCreateEstimate = estimatedMinutes
        return try createResult.get()
    }

    nonisolated func updateTask(id: String, dto: UpdateTaskDTO) async throws -> TaskModel {
        updateCallCount += 1
        capturedUpdateId = id
        capturedUpdateDTO = dto
        return try updateResult.get()
    }

    nonisolated func completeTask(id: String) async throws -> TaskModel {
        completeCallCount += 1
        capturedCompleteId = id
        return try completeResult.get()
    }

    nonisolated func reorderTasks(playbookId: String, lane: TaskLane, taskIds: [String]) async throws {
        reorderCallCount += 1
        capturedReorderLane = lane
        capturedReorderTaskIds = taskIds
        try reorderResult.get()
    }

    nonisolated func deleteTask(id: String) async throws {
        deleteCallCount += 1
        try deleteResult.get()
    }
}

// MARK: - Stub Section Service

/// Minimal stub for SectionServiceProtocol used when tests don't exercise section logic.
private final class StubSectionService: SectionServiceProtocol, @unchecked Sendable {
    nonisolated func fetchSections(playbookId: String, updatedSince: Date?) async throws -> [SectionModel] { [] }
    nonisolated func updateSection(playbookId: String, sectionType: SectionType, content: String) async throws -> SectionModel {
        SectionModel(playbookId: playbookId, sectionType: sectionType, content: content)
    }
}

// MARK: - Stub Weekly Plan Service

/// Minimal stub for WeeklyPlanServiceProtocol used when tests don't exercise weekly plan logic.
private final class StubWeeklyPlanService: WeeklyPlanServiceProtocol, @unchecked Sendable {
    nonisolated func getWeeklyStatus(playbookId: String) async throws -> WeeklyCycleModel {
        WeeklyCycleModel(playbookId: playbookId, weekStartDate: .now)
    }
    nonisolated func createWeeklyPlan(playbookId: String, taskIds: [String]) async throws -> WeeklyCycleModel {
        WeeklyCycleModel(playbookId: playbookId, weekStartDate: .now, totalCount: taskIds.count)
    }
    nonisolated func fetchWeeklyCycles(playbookId: String) async throws -> [WeeklyCycleModel] { [] }
}

// MARK: - Test Helpers

private func makeSamplePlaybook() -> PlaybookModel {
    PlaybookModel(id: "pb-1", title: "Test Playbook")
}

private func makeSampleTasks() -> [TaskModel] {
    [
        TaskModel(id: "t-1", playbookId: "pb-1", title: "Now Task 1", lane: .now, orderIndex: 0),
        TaskModel(id: "t-2", playbookId: "pb-1", title: "Now Task 2", lane: .now, orderIndex: 1),
        TaskModel(id: "t-3", playbookId: "pb-1", title: "Next Task", lane: .next, orderIndex: 0),
        TaskModel(id: "t-4", playbookId: "pb-1", title: "Later Task", lane: .later, orderIndex: 0),
    ]
}

private func makeMixedStatusTasks() -> [TaskModel] {
    [
        TaskModel(id: "t-1", playbookId: "pb-1", title: "Open Task", lane: .now, status: .open, orderIndex: 0),
        TaskModel(id: "t-2", playbookId: "pb-1", title: "Done Task", lane: .now, status: .done, orderIndex: 1, completedAt: .now),
    ]
}

// MARK: - PlaybookHomeViewModel Tests

@Suite("PlaybookHomeViewModel", .serialized)
struct PlaybookHomeViewModelTests {

    // MARK: - Load

    @Test("loadTasks fetches and populates allTasks")
    @MainActor func loadTasksSuccess() async throws {
        let mockService = MockTaskService()
        mockService.fetchResult = .success(makeSampleTasks())
        let vm = PlaybookHomeViewModel(playbook: makeSamplePlaybook(), taskService: mockService, sectionService: StubSectionService(), weeklyPlanService: StubWeeklyPlanService())

        vm.loadTasks()
        try await Task.sleep(for: .milliseconds(50))

        #expect(mockService.fetchCallCount == 1)
        #expect(vm.allTasks.count == 4)
        #expect(vm.error == nil)
        #expect(vm.isLoading == false)
    }

    @Test("loadTasks network error sets error string")
    @MainActor func loadTasksError() async throws {
        let mockService = MockTaskService()
        mockService.fetchResult = .failure(.networkError("timeout"))
        let vm = PlaybookHomeViewModel(playbook: makeSamplePlaybook(), taskService: mockService, sectionService: StubSectionService(), weeklyPlanService: StubWeeklyPlanService())

        vm.loadTasks()
        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.error == "Network error. Please check your connection.")
        #expect(vm.allTasks.isEmpty)
        #expect(vm.isLoading == false)
    }

    // MARK: - Refresh

    @Test("refresh calls fetch and updates list")
    @MainActor func refreshCallsFetch() async throws {
        let mockService = MockTaskService()
        mockService.fetchResult = .success(makeSampleTasks())
        let vm = PlaybookHomeViewModel(playbook: makeSamplePlaybook(), taskService: mockService, sectionService: StubSectionService(), weeklyPlanService: StubWeeklyPlanService())

        await vm.refresh()

        #expect(mockService.fetchCallCount == 1)
        #expect(vm.allTasks.count == 4)
        #expect(vm.error == nil)
    }

    // MARK: - Lane Filtering

    @Test("tasksInCurrentLane returns only NOW tasks by default")
    @MainActor func laneFilteringNow() {
        let mockService = MockTaskService()
        let vm = PlaybookHomeViewModel(playbook: makeSamplePlaybook(), taskService: mockService, sectionService: StubSectionService(), weeklyPlanService: StubWeeklyPlanService())
        vm.allTasks = makeSampleTasks()

        let nowTasks = vm.tasksInCurrentLane
        #expect(nowTasks.count == 2)
        #expect(nowTasks.allSatisfy { $0.lane == .now })
    }

    @Test("selectLane switches to NEXT and filters correctly")
    @MainActor func laneFilteringNext() {
        let mockService = MockTaskService()
        let vm = PlaybookHomeViewModel(playbook: makeSamplePlaybook(), taskService: mockService, sectionService: StubSectionService(), weeklyPlanService: StubWeeklyPlanService())
        vm.allTasks = makeSampleTasks()

        vm.selectLane(.next)

        let nextTasks = vm.tasksInCurrentLane
        #expect(nextTasks.count == 1)
        #expect(nextTasks.first?.title == "Next Task")
    }

    @Test("tasksInCurrentLane excludes completed tasks")
    @MainActor func laneFilteringHidesDone() {
        let mockService = MockTaskService()
        let vm = PlaybookHomeViewModel(playbook: makeSamplePlaybook(), taskService: mockService, sectionService: StubSectionService(), weeklyPlanService: StubWeeklyPlanService())
        vm.allTasks = makeMixedStatusTasks()

        let tasks = vm.tasksInCurrentLane
        #expect(tasks.count == 1)
        #expect(tasks.first?.title == "Open Task")
    }

    @Test("taskCounts returns correct counts per lane")
    @MainActor func taskCountsPerLane() {
        let mockService = MockTaskService()
        let vm = PlaybookHomeViewModel(playbook: makeSamplePlaybook(), taskService: mockService, sectionService: StubSectionService(), weeklyPlanService: StubWeeklyPlanService())
        vm.allTasks = makeSampleTasks()

        let counts = vm.taskCounts
        #expect(counts[.now] == 2)
        #expect(counts[.next] == 1)
        #expect(counts[.later] == 1)
    }

    // MARK: - Complete

    @Test("completeTask calls service and updates task status in allTasks")
    @MainActor func completeTaskSuccess() async throws {
        let mockService = MockTaskService()
        let completedTask = TaskModel(id: "t-1", playbookId: "pb-1", title: "Now Task 1", lane: .now, status: .done, completedAt: .now)
        mockService.completeResult = .success(completedTask)

        let vm = PlaybookHomeViewModel(playbook: makeSamplePlaybook(), taskService: mockService, sectionService: StubSectionService(), weeklyPlanService: StubWeeklyPlanService())
        vm.allTasks = makeSampleTasks()

        vm.completeTask(id: "t-1")
        try await Task.sleep(for: .milliseconds(50))

        #expect(mockService.completeCallCount == 1)
        #expect(mockService.capturedCompleteId == "t-1")
        #expect(vm.allTasks.first(where: { $0.id == "t-1" })?.status == .done)
        #expect(vm.error == nil)
    }

    @Test("completeTask error sets error string")
    @MainActor func completeTaskError() async throws {
        let mockService = MockTaskService()
        mockService.completeResult = .failure(.serverError("Server error"))

        let vm = PlaybookHomeViewModel(playbook: makeSamplePlaybook(), taskService: mockService, sectionService: StubSectionService(), weeklyPlanService: StubWeeklyPlanService())
        vm.allTasks = makeSampleTasks()

        vm.completeTask(id: "t-1")
        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.error == "Something went wrong. Please try again.")
    }

    // MARK: - Move

    @Test("moveTask calls service with lane change and updates allTasks")
    @MainActor func moveTaskSuccess() async throws {
        let mockService = MockTaskService()
        let movedTask = TaskModel(id: "t-1", playbookId: "pb-1", title: "Now Task 1", lane: .next, orderIndex: 0)
        mockService.updateResult = .success(movedTask)

        let vm = PlaybookHomeViewModel(playbook: makeSamplePlaybook(), taskService: mockService, sectionService: StubSectionService(), weeklyPlanService: StubWeeklyPlanService())
        vm.allTasks = makeSampleTasks()

        vm.moveTask(id: "t-1", toLane: .next)
        try await Task.sleep(for: .milliseconds(50))

        #expect(mockService.updateCallCount == 1)
        #expect(mockService.capturedUpdateId == "t-1")
        #expect(mockService.capturedUpdateDTO?.lane == "NEXT")
        #expect(vm.allTasks.first(where: { $0.id == "t-1" })?.lane == .next)
        #expect(vm.error == nil)
    }

    // MARK: - Reorder

    @Test("reorderTasks updates local orderIndex and calls service")
    @MainActor func reorderTasksSuccess() async throws {
        let mockService = MockTaskService()
        let vm = PlaybookHomeViewModel(playbook: makeSamplePlaybook(), taskService: mockService, sectionService: StubSectionService(), weeklyPlanService: StubWeeklyPlanService())
        vm.allTasks = makeSampleTasks()

        // Reverse the order of NOW tasks.
        vm.reorderTasks(ids: ["t-2", "t-1"])
        try await Task.sleep(for: .milliseconds(50))

        // Local order should be updated immediately.
        #expect(vm.allTasks.first(where: { $0.id == "t-2" })?.orderIndex == 0)
        #expect(vm.allTasks.first(where: { $0.id == "t-1" })?.orderIndex == 1)

        // Service should have been called.
        #expect(mockService.reorderCallCount == 1)
        #expect(mockService.capturedReorderTaskIds == ["t-2", "t-1"])
        #expect(mockService.capturedReorderLane == .now)
        #expect(vm.error == nil)
    }

    // MARK: - Empty State

    @Test("emptyStateMessage returns correct message per lane")
    @MainActor func emptyStateMessages() {
        let mockService = MockTaskService()
        let vm = PlaybookHomeViewModel(playbook: makeSamplePlaybook(), taskService: mockService, sectionService: StubSectionService(), weeklyPlanService: StubWeeklyPlanService())

        vm.selectLane(.now)
        #expect(vm.emptyStateMessage == "No active tasks. Move a task to Now to get started.")

        vm.selectLane(.next)
        #expect(vm.emptyStateMessage == "Nothing queued up yet.")

        vm.selectLane(.later)
        #expect(vm.emptyStateMessage == "Your backlog is empty.")
    }

    // MARK: - Detail Sheet

    @Test("selectTask and clearSelectedTask manage detail sheet state")
    @MainActor func selectAndClearTask() {
        let mockService = MockTaskService()
        let vm = PlaybookHomeViewModel(playbook: makeSamplePlaybook(), taskService: mockService, sectionService: StubSectionService(), weeklyPlanService: StubWeeklyPlanService())
        let task = TaskModel(playbookId: "pb-1", title: "Test Task")

        vm.selectTask(task)
        #expect(vm.selectedTask?.title == "Test Task")

        vm.clearSelectedTask()
        #expect(vm.selectedTask == nil)
    }

    // MARK: - Sync Status

    @Test("syncStatusValue defaults to .synced when no engine")
    @MainActor func syncStatusDefaultsSynced() {
        let vm = PlaybookHomeViewModel(playbook: makeSamplePlaybook(), taskService: MockTaskService(), sectionService: StubSectionService(), weeklyPlanService: StubWeeklyPlanService())

        #expect(vm.syncStatusValue == .synced)
    }

    @Test("syncStatusValue reflects engine status")
    @MainActor func syncStatusReflectsEngine() throws {
        let engine = try makeSyncEngineForHomeTests()
        let vm = PlaybookHomeViewModel(playbook: makeSamplePlaybook(), taskService: MockTaskService(), sectionService: StubSectionService(), weeklyPlanService: StubWeeklyPlanService(), syncEngine: engine)

        engine.status.value = .offline
        #expect(vm.syncStatusValue == .offline)

        engine.status.value = .pending(3)
        #expect(vm.syncStatusValue == .pending(3))

        engine.status.value = .error("Network failure")
        #expect(vm.syncStatusValue == .error("Network failure"))

        engine.status.value = .synced
        #expect(vm.syncStatusValue == .synced)
    }

    @Test("syncErrorMessage returns message for error status")
    @MainActor func syncErrorMessage() throws {
        let engine = try makeSyncEngineForHomeTests()
        let vm = PlaybookHomeViewModel(playbook: makeSamplePlaybook(), taskService: MockTaskService(), sectionService: StubSectionService(), weeklyPlanService: StubWeeklyPlanService(), syncEngine: engine)

        #expect(vm.syncErrorMessage == nil)

        engine.status.value = .error("Connection refused")
        #expect(vm.syncErrorMessage == "Connection refused")

        engine.status.value = .synced
        #expect(vm.syncErrorMessage == nil)
    }

    // MARK: - Per-Item Sync State

    @Test("taskSyncState returns nil when no sync engine")
    @MainActor func taskSyncStateWithoutEngine() {
        let vm = PlaybookHomeViewModel(playbook: makeSamplePlaybook(), taskService: MockTaskService(), sectionService: StubSectionService(), weeklyPlanService: StubWeeklyPlanService())
        #expect(vm.taskSyncState(for: "t-1") == nil)
    }

    @Test("taskSyncState returns state from mutation queue entityStates")
    @MainActor func taskSyncStateFromQueue() throws {
        let engine = try makeSyncEngineForHomeTests()
        let vm = PlaybookHomeViewModel(playbook: makeSamplePlaybook(), taskService: MockTaskService(), sectionService: StubSectionService(), weeklyPlanService: StubWeeklyPlanService(), syncEngine: engine)

        engine.mutationQueue.entityStates["t-1"] = .pending

        #expect(vm.taskSyncState(for: "t-1") == .pending)
        #expect(vm.taskSyncState(for: "t-2") == nil)
    }

    @Test("taskSyncState returns .failed state from mutation queue")
    @MainActor func taskSyncStateReturnsFailed() throws {
        let engine = try makeSyncEngineForHomeTests()
        let vm = PlaybookHomeViewModel(playbook: makeSamplePlaybook(), taskService: MockTaskService(), sectionService: StubSectionService(), weeklyPlanService: StubWeeklyPlanService(), syncEngine: engine)

        engine.mutationQueue.entityStates["t-1"] = .failed(retryCount: 2)

        #expect(vm.taskSyncState(for: "t-1") == .failed(retryCount: 2))
    }
}

// MARK: - Sync Engine Helper

private let homeTestBaseURL = URL(string: "https://api.test.ideapilot.app")!

private func makeSyncEngineForHomeTests() throws -> SyncEngine {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: PlaybookModel.self, TaskModel.self, SectionModel.self, WeeklyCycleModel.self, MutationEntry.self,
        configurations: config
    )
    let apiClient = APIClient(baseURL: homeTestBaseURL, session: URLSession.shared)
    return SyncEngine(apiClient: apiClient, modelContainer: container)
}
