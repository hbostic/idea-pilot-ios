//
//  WeeklyPlanViewModelTests.swift
//  idea-pilotTests
//
//  Unit tests for WeeklyPlanViewModel — the 3-step weekly planning flow.
//

import Foundation
import Testing
@testable import idea_pilot

// MARK: - Mock Weekly Plan Service

/// Mock implementation of `WeeklyPlanServiceProtocol` for ViewModel testing.
final class MockWeeklyPlanService: WeeklyPlanServiceProtocol, @unchecked Sendable {

    nonisolated(unsafe) var getWeeklyStatusResult: Result<WeeklyCycleModel, WeeklyPlanError> = .success(
        WeeklyCycleModel(playbookId: "pb-1", weekStartDate: .now, completedCount: 3, totalCount: 5)
    )
    nonisolated(unsafe) var createWeeklyPlanResult: Result<WeeklyCycleModel, WeeklyPlanError> = .success(
        WeeklyCycleModel(playbookId: "pb-1", weekStartDate: .now, totalCount: 3)
    )
    nonisolated(unsafe) var fetchWeeklyCyclesResult: Result<[WeeklyCycleModel], WeeklyPlanError> = .success([])

    nonisolated(unsafe) var getWeeklyStatusCallCount = 0
    nonisolated(unsafe) var createWeeklyPlanCallCount = 0
    nonisolated(unsafe) var capturedCreateTaskIds: [String]?
    nonisolated(unsafe) var capturedCreatePlaybookId: String?

    nonisolated func getWeeklyStatus(playbookId: String) async throws -> WeeklyCycleModel {
        getWeeklyStatusCallCount += 1
        return try getWeeklyStatusResult.get()
    }

    nonisolated func createWeeklyPlan(playbookId: String, taskIds: [String]) async throws -> WeeklyCycleModel {
        createWeeklyPlanCallCount += 1
        capturedCreatePlaybookId = playbookId
        capturedCreateTaskIds = taskIds
        return try createWeeklyPlanResult.get()
    }

    nonisolated func fetchWeeklyCycles(playbookId: String) async throws -> [WeeklyCycleModel] {
        try fetchWeeklyCyclesResult.get()
    }
}

// MARK: - Test Helpers

private func makePlaybook() -> PlaybookModel {
    PlaybookModel(id: "pb-1", title: "Test Playbook")
}

/// Creates tasks across multiple lanes with mixed statuses.
private func makeMixedTasks() -> [TaskModel] {
    [
        // Now lane — incomplete
        TaskModel(id: "t-1", playbookId: "pb-1", title: "Now Open 1", lane: .now, status: .open, orderIndex: 0),
        TaskModel(id: "t-2", playbookId: "pb-1", title: "Now Open 2", lane: .now, status: .open, orderIndex: 1),
        // Now lane — completed
        TaskModel(id: "t-3", playbookId: "pb-1", title: "Now Done", lane: .now, status: .done, orderIndex: 2, completedAt: .now),
        // Next lane — available for selection
        TaskModel(id: "t-4", playbookId: "pb-1", title: "Next Task 1", lane: .next, estimatedMinutes: 30, orderIndex: 0),
        TaskModel(id: "t-5", playbookId: "pb-1", title: "Next Task 2", lane: .next, estimatedMinutes: 60, orderIndex: 1),
        TaskModel(id: "t-6", playbookId: "pb-1", title: "Next Task 3", lane: .next, estimatedMinutes: 90, orderIndex: 2),
        // Later lane
        TaskModel(id: "t-7", playbookId: "pb-1", title: "Later Task", lane: .later, orderIndex: 0),
    ]
}

/// Creates tasks with no incomplete Now tasks (all done or in other lanes).
private func makeNoIncompleteTasks() -> [TaskModel] {
    [
        TaskModel(id: "t-1", playbookId: "pb-1", title: "Now Done", lane: .now, status: .done, orderIndex: 0, completedAt: .now),
        TaskModel(id: "t-2", playbookId: "pb-1", title: "Next Task", lane: .next, estimatedMinutes: 60, orderIndex: 0),
    ]
}

/// Creates 7 Next lane tasks for testing the >5 warning.
private func makeManyNextTasks() -> [TaskModel] {
    (0..<7).map { i in
        TaskModel(id: "t-\(i)", playbookId: "pb-1", title: "Next \(i)", lane: .next, estimatedMinutes: 30, orderIndex: i)
    }
}

private func makeVM(
    taskService: MockTaskService = MockTaskService(),
    weeklyPlanService: MockWeeklyPlanService = MockWeeklyPlanService()
) -> WeeklyPlanViewModel {
    WeeklyPlanViewModel(
        playbook: makePlaybook(),
        taskService: taskService,
        weeklyPlanService: weeklyPlanService
    )
}

// MARK: - Tests

@Suite("WeeklyPlanViewModel", .serialized)
struct WeeklyPlanViewModelTests {

    // MARK: - Default State

    @Test("default state is review step with empty selections")
    @MainActor func defaultState() {
        let vm = makeVM()

        #expect(vm.currentStep == .review)
        #expect(vm.isLoading == false)
        #expect(vm.isSubmitting == false)
        #expect(vm.error == nil)
        #expect(vm.selectedTaskIds.isEmpty)
        #expect(vm.dispositions.isEmpty)
        #expect(vm.lastWeekCycle == nil)
        #expect(vm.allTasks.isEmpty)
        #expect(vm.newWeeklyCycle == nil)
    }

    // MARK: - Load Data

    @Test("loadData fetches tasks and weekly status")
    @MainActor func loadDataSuccess() async throws {
        let taskService = MockTaskService()
        taskService.fetchResult = .success(makeMixedTasks())
        let weeklyPlanService = MockWeeklyPlanService()

        let vm = makeVM(taskService: taskService, weeklyPlanService: weeklyPlanService)
        vm.loadData()
        try await Task.sleep(for: .milliseconds(50))

        #expect(taskService.fetchCallCount == 1)
        #expect(weeklyPlanService.getWeeklyStatusCallCount == 1)
        #expect(vm.allTasks.count == 7)
        #expect(vm.lastWeekCycle != nil)
        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
    }

    @Test("loadData initializes dispositions for incomplete Now tasks")
    @MainActor func loadDataInitializesDispositions() async throws {
        let taskService = MockTaskService()
        taskService.fetchResult = .success(makeMixedTasks())

        let vm = makeVM(taskService: taskService)
        vm.loadData()
        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.dispositions.count == 2)
        #expect(vm.dispositions["t-1"] == .keepInNow)
        #expect(vm.dispositions["t-2"] == .keepInNow)
    }

    @Test("loadData skips review when no incomplete Now tasks")
    @MainActor func loadDataSkipsReview() async throws {
        let taskService = MockTaskService()
        taskService.fetchResult = .success(makeNoIncompleteTasks())

        let vm = makeVM(taskService: taskService)
        vm.loadData()
        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.currentStep == .select)
        #expect(vm.dispositions.isEmpty)
    }

    @Test("loadData handles 404 weekly status gracefully")
    @MainActor func loadDataHandles404() async throws {
        let taskService = MockTaskService()
        taskService.fetchResult = .success(makeMixedTasks())
        let weeklyPlanService = MockWeeklyPlanService()
        weeklyPlanService.getWeeklyStatusResult = .failure(.notFound)

        let vm = makeVM(taskService: taskService, weeklyPlanService: weeklyPlanService)
        vm.loadData()
        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.lastWeekCycle == nil)
        #expect(vm.error == nil)
        #expect(vm.allTasks.count == 7)
    }

    @Test("loadData network error sets error string")
    @MainActor func loadDataNetworkError() async throws {
        let taskService = MockTaskService()
        taskService.fetchResult = .failure(.networkError("timeout"))

        let vm = makeVM(taskService: taskService)
        vm.loadData()
        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.error == "Network error. Please check your connection.")
        #expect(vm.allTasks.isEmpty)
    }

    @Test("loadData weekly plan server error sets error string")
    @MainActor func loadDataWeeklyPlanError() async throws {
        let taskService = MockTaskService()
        taskService.fetchResult = .success(makeMixedTasks())
        let weeklyPlanService = MockWeeklyPlanService()
        weeklyPlanService.getWeeklyStatusResult = .failure(.serverError("Server error"))

        let vm = makeVM(taskService: taskService, weeklyPlanService: weeklyPlanService)
        vm.loadData()
        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.error == "Something went wrong. Please try again.")
    }

    // MARK: - Computed Filters

    @Test("incompleteTasks filters Now lane open tasks only")
    @MainActor func incompleteTasksFilter() {
        let vm = makeVM()
        vm.allTasks = makeMixedTasks()

        let incomplete = vm.incompleteTasks
        #expect(incomplete.count == 2)
        #expect(incomplete.allSatisfy { $0.lane == .now && $0.status == .open })
        #expect(incomplete[0].id == "t-1")
        #expect(incomplete[1].id == "t-2")
    }

    @Test("completedTasks filters Now lane done tasks only")
    @MainActor func completedTasksFilter() {
        let vm = makeVM()
        vm.allTasks = makeMixedTasks()

        let completed = vm.completedTasks
        #expect(completed.count == 1)
        #expect(completed.first?.id == "t-3")
        #expect(completed.first?.status == .done)
    }

    @Test("nextLaneTasks filters Next lane open tasks only")
    @MainActor func nextLaneTasksFilter() {
        let vm = makeVM()
        vm.allTasks = makeMixedTasks()

        let nextTasks = vm.nextLaneTasks
        #expect(nextTasks.count == 3)
        #expect(nextTasks.allSatisfy { $0.lane == .next && $0.status == .open })
        #expect(nextTasks[0].id == "t-4")
        #expect(nextTasks[1].id == "t-5")
        #expect(nextTasks[2].id == "t-6")
    }

    // MARK: - Step 1 — Dispositions

    @Test("setDisposition updates disposition for task")
    @MainActor func setDisposition() {
        let vm = makeVM()
        vm.allTasks = makeMixedTasks()
        vm.dispositions["t-1"] = .keepInNow

        vm.setDisposition(taskId: "t-1", .moveToNext)

        #expect(vm.dispositions["t-1"] == .moveToNext)
    }

    @Test("applyDispositionsAndAdvance moves tasks and advances to select")
    @MainActor func applyDispositionsSuccess() async throws {
        let taskService = MockTaskService()
        let movedTask = TaskModel(id: "t-1", playbookId: "pb-1", title: "Now Open 1", lane: .next, orderIndex: 0)
        taskService.updateResult = .success(movedTask)

        let vm = makeVM(taskService: taskService)
        vm.allTasks = makeMixedTasks()
        vm.dispositions = [
            "t-1": .moveToNext,
            "t-2": .keepInNow,
        ]

        vm.applyDispositionsAndAdvance()
        try await Task.sleep(for: .milliseconds(50))

        // Only t-1 should have been updated (moveToNext), t-2 is keepInNow.
        #expect(taskService.updateCallCount == 1)
        #expect(taskService.capturedUpdateId == "t-1")
        #expect(taskService.capturedUpdateDTO?.lane == "NEXT")
        #expect(vm.currentStep == .select)
        #expect(vm.isSubmitting == false)
        #expect(vm.error == nil)
    }

    @Test("applyDispositionsAndAdvance skips update for keepInNow")
    @MainActor func applyDispositionsKeepInNow() async throws {
        let taskService = MockTaskService()

        let vm = makeVM(taskService: taskService)
        vm.allTasks = makeMixedTasks()
        vm.dispositions = [
            "t-1": .keepInNow,
            "t-2": .keepInNow,
        ]

        vm.applyDispositionsAndAdvance()
        try await Task.sleep(for: .milliseconds(50))

        #expect(taskService.updateCallCount == 0)
        #expect(vm.currentStep == .select)
    }

    @Test("applyDispositionsAndAdvance error sets error and stays on review")
    @MainActor func applyDispositionsError() async throws {
        let taskService = MockTaskService()
        taskService.updateResult = .failure(.serverError("fail"))

        let vm = makeVM(taskService: taskService)
        vm.allTasks = makeMixedTasks()
        vm.dispositions = ["t-1": .moveToLater]

        vm.applyDispositionsAndAdvance()
        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.error == "Something went wrong. Please try again.")
        #expect(vm.currentStep == .review)
    }

    // MARK: - Step 2 — Selection

    @Test("toggleTaskSelection adds and removes task IDs")
    @MainActor func toggleSelection() {
        let vm = makeVM()

        vm.toggleTaskSelection("t-4")
        #expect(vm.selectedTaskIds.contains("t-4"))

        vm.toggleTaskSelection("t-4")
        #expect(!vm.selectedTaskIds.contains("t-4"))
    }

    @Test("isTaskSelected returns true for selected tasks")
    @MainActor func isTaskSelected() {
        let vm = makeVM()
        vm.selectedTaskIds = ["t-4", "t-5"]

        #expect(vm.isTaskSelected("t-4") == true)
        #expect(vm.isTaskSelected("t-5") == true)
        #expect(vm.isTaskSelected("t-6") == false)
    }

    @Test("selectedCount returns correct count")
    @MainActor func selectedCount() {
        let vm = makeVM()
        vm.selectedTaskIds = ["t-4", "t-5", "t-6"]

        #expect(vm.selectedCount == 3)
    }

    @Test("totalEstimatedMinutes sums selected tasks")
    @MainActor func totalEstimatedMinutes() {
        let vm = makeVM()
        vm.allTasks = makeMixedTasks()
        vm.selectedTaskIds = ["t-4", "t-5", "t-6"]  // 30 + 60 + 90

        #expect(vm.totalEstimatedMinutes == 180)
    }

    @Test("totalEstimatedMinutes updates when selection changes")
    @MainActor func totalEstimatedMinutesUpdates() {
        let vm = makeVM()
        vm.allTasks = makeMixedTasks()
        vm.selectedTaskIds = ["t-4", "t-5", "t-6"]  // 30 + 60 + 90

        #expect(vm.totalEstimatedMinutes == 180)

        vm.toggleTaskSelection("t-6")  // Remove 90min task

        #expect(vm.totalEstimatedMinutes == 90)  // 30 + 60
    }

    @Test("showAmbitiousWarning false at 5 tasks")
    @MainActor func warningFalseAt5() {
        let vm = makeVM()
        vm.allTasks = makeManyNextTasks()
        vm.selectedTaskIds = Set(["t-0", "t-1", "t-2", "t-3", "t-4"])

        #expect(vm.selectedCount == 5)
        #expect(vm.showAmbitiousWarning == false)
    }

    @Test("showAmbitiousWarning true at 6 tasks")
    @MainActor func warningTrueAt6() {
        let vm = makeVM()
        vm.allTasks = makeManyNextTasks()
        vm.selectedTaskIds = Set(["t-0", "t-1", "t-2", "t-3", "t-4", "t-5"])

        #expect(vm.selectedCount == 6)
        #expect(vm.showAmbitiousWarning == true)
    }

    @Test("canCreatePlan false when none selected")
    @MainActor func canCreatePlanFalseEmpty() {
        let vm = makeVM()

        #expect(vm.canCreatePlan == false)
    }

    @Test("canCreatePlan true when tasks selected")
    @MainActor func canCreatePlanTrue() {
        let vm = makeVM()
        vm.selectedTaskIds = ["t-4"]

        #expect(vm.canCreatePlan == true)
    }

    @Test("canCreatePlan false when submitting")
    @MainActor func canCreatePlanFalseSubmitting() {
        let vm = makeVM()
        vm.selectedTaskIds = ["t-4"]
        vm.isSubmitting = true

        #expect(vm.canCreatePlan == false)
    }

    // MARK: - Plan Creation (Step 2 → 3)

    @Test("createPlanAndAdvance calls service with correct task IDs")
    @MainActor func createPlanCorrectIds() async throws {
        let weeklyPlanService = MockWeeklyPlanService()
        let vm = makeVM(weeklyPlanService: weeklyPlanService)
        vm.selectedTaskIds = ["t-4", "t-5"]

        vm.createPlanAndAdvance()
        try await Task.sleep(for: .milliseconds(50))

        #expect(weeklyPlanService.createWeeklyPlanCallCount == 1)
        #expect(weeklyPlanService.capturedCreatePlaybookId == "pb-1")
        #expect(Set(weeklyPlanService.capturedCreateTaskIds ?? []) == Set(["t-4", "t-5"]))
    }

    @Test("createPlanAndAdvance sets newWeeklyCycle and advances to confirm")
    @MainActor func createPlanAdvances() async throws {
        let weeklyPlanService = MockWeeklyPlanService()
        let vm = makeVM(weeklyPlanService: weeklyPlanService)
        vm.selectedTaskIds = ["t-4"]

        vm.createPlanAndAdvance()
        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.newWeeklyCycle != nil)
        #expect(vm.currentStep == .confirm)
        #expect(vm.isSubmitting == false)
        #expect(vm.error == nil)
    }

    @Test("createPlanAndAdvance error sets error and stays on select")
    @MainActor func createPlanError() async throws {
        let weeklyPlanService = MockWeeklyPlanService()
        weeklyPlanService.createWeeklyPlanResult = .failure(.serverError("Server error"))
        let vm = makeVM(weeklyPlanService: weeklyPlanService)
        vm.selectedTaskIds = ["t-4"]

        vm.createPlanAndAdvance()
        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.error == "Something went wrong. Please try again.")
        #expect(vm.currentStep != .confirm)
        #expect(vm.newWeeklyCycle == nil)
    }

    @Test("createPlanAndAdvance no-op when none selected")
    @MainActor func createPlanNoOp() async throws {
        let weeklyPlanService = MockWeeklyPlanService()
        let vm = makeVM(weeklyPlanService: weeklyPlanService)

        vm.createPlanAndAdvance()
        try await Task.sleep(for: .milliseconds(50))

        #expect(weeklyPlanService.createWeeklyPlanCallCount == 0)
        #expect(vm.currentStep == .review)
    }

    // MARK: - Navigation

    @Test("canGoBack false on review step")
    @MainActor func canGoBackReview() {
        let vm = makeVM()
        vm.currentStep = .review

        #expect(vm.canGoBack == false)
    }

    @Test("canGoBack true on select when review was not skipped")
    @MainActor func canGoBackSelectWithReview() {
        let vm = makeVM()
        vm.allTasks = makeMixedTasks()  // Has incomplete Now tasks
        vm.currentStep = .select

        #expect(vm.canGoBack == true)
    }

    @Test("canGoBack false on select when review was skipped")
    @MainActor func canGoBackSelectSkipped() {
        let vm = makeVM()
        vm.allTasks = makeNoIncompleteTasks()  // No incomplete Now tasks
        vm.currentStep = .select

        #expect(vm.shouldSkipReview == true)
        #expect(vm.canGoBack == false)
    }

    @Test("canGoBack false on confirm step")
    @MainActor func canGoBackConfirm() {
        let vm = makeVM()
        vm.currentStep = .confirm

        #expect(vm.canGoBack == false)
    }

    @Test("goBack returns to review from select")
    @MainActor func goBackFromSelect() {
        let vm = makeVM()
        vm.allTasks = makeMixedTasks()
        vm.currentStep = .select

        vm.goBack()

        #expect(vm.currentStep == .review)
    }
}
