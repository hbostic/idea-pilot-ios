//
//  WeeklyPlanViewModel.swift
//  idea-pilot
//
//  ViewModel for the 3-step Weekly Plan ritual flow.
//  Manages review of last week, selection of this week's tasks,
//  and confirmation before dismissing.
//

import Foundation

// MARK: - WeeklyPlanStep

/// The three steps of the weekly planning ritual.
enum WeeklyPlanStep: Int, CaseIterable, Sendable {
    /// Review last week: triage incomplete tasks.
    case review = 0
    /// Select tasks from the Next lane for this week.
    case select = 1
    /// Confirm the new weekly plan.
    case confirm = 2

    /// Human-readable title for each step.
    var title: String {
        switch self {
        case .review:  "Review"
        case .select:  "Select"
        case .confirm: "Confirm"
        }
    }
}

// MARK: - TaskDisposition

/// How an incomplete task from last week should be handled.
enum TaskDisposition: String, CaseIterable, Sendable {
    /// Keep the task in the Now lane.
    case keepInNow
    /// Move the task to the Next lane.
    case moveToNext
    /// Move the task to the Later lane.
    case moveToLater
}

// MARK: - WeeklyPlanViewModel

/// Drives the 3-step Weekly Plan flow: Review last week, Select this week's tasks, Confirm.
///
/// Uses `@Observable` for modern SwiftUI data flow. Since the project uses
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, this class runs on MainActor
/// by default — safe for driving UI.
@Observable
final class WeeklyPlanViewModel {

    // MARK: - Step Navigation

    /// The current step in the 3-step flow.
    var currentStep: WeeklyPlanStep = .review

    // MARK: - Loading State

    var isLoading = false
    var isSubmitting = false
    var error: String?

    // MARK: - Step 1 — Review State

    /// Last week's cycle stats (completedCount / totalCount).
    var lastWeekCycle: WeeklyCycleModel?

    /// All tasks fetched for this playbook.
    var allTasks: [TaskModel] = []

    /// Disposition choices for each incomplete Now task, keyed by task ID.
    /// Defaults to `.keepInNow` for every incomplete task.
    var dispositions: [String: TaskDisposition] = [:]

    // MARK: - Step 2 — Select State

    /// Set of task IDs the user has selected from the Next lane.
    var selectedTaskIds: Set<String> = []

    // MARK: - Step 3 — Confirm State

    /// The newly created weekly cycle, set after plan creation succeeds.
    var newWeeklyCycle: WeeklyCycleModel?

    // MARK: - Computed — Step 1

    /// Incomplete tasks in the Now lane (open status).
    var incompleteTasks: [TaskModel] {
        allTasks
            .filter { $0.lane == .now && $0.status == .open }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    /// Completed tasks in the Now lane (for the collapsible reference list).
    var completedTasks: [TaskModel] {
        allTasks
            .filter { $0.lane == .now && $0.status == .done }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    /// Whether Step 1 (Review) should be skipped because there are no incomplete Now tasks.
    var shouldSkipReview: Bool {
        incompleteTasks.isEmpty
    }

    // MARK: - Computed — Step 2

    /// Tasks in the Next lane (open only), available for selection.
    var nextLaneTasks: [TaskModel] {
        allTasks
            .filter { $0.lane == .next && $0.status == .open }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    /// Number of tasks currently selected.
    var selectedCount: Int {
        selectedTaskIds.count
    }

    /// Total estimated minutes across all selected tasks.
    var totalEstimatedMinutes: Int {
        allTasks
            .filter { selectedTaskIds.contains($0.id) }
            .reduce(0) { $0 + $1.estimatedMinutes }
    }

    /// Soft warning if the user has selected more than 5 tasks.
    var showAmbitiousWarning: Bool {
        selectedCount > 5
    }

    /// Whether the "Plan Week" button should be enabled.
    var canCreatePlan: Bool {
        selectedCount > 0 && !isSubmitting
    }

    // MARK: - Computed — Step 3

    /// The selected tasks for the confirmation summary (read-only display).
    var selectedTasks: [TaskModel] {
        allTasks
            .filter { selectedTaskIds.contains($0.id) }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    // MARK: - Computed — Navigation

    /// Whether the user can navigate backward from the current step.
    var canGoBack: Bool {
        switch currentStep {
        case .review: false
        case .select: !shouldSkipReview && !isSubmitting
        case .confirm: false
        }
    }

    // MARK: - Dependencies

    let playbook: PlaybookModel
    private let taskService: any TaskServiceProtocol
    private let weeklyPlanService: any WeeklyPlanServiceProtocol

    // MARK: - Init

    /// Creates a WeeklyPlanViewModel.
    ///
    /// - Parameters:
    ///   - playbook: The playbook this weekly plan is for.
    ///   - taskService: The service for task API calls (fetch, update).
    ///   - weeklyPlanService: The service for weekly plan API calls (status, create).
    init(
        playbook: PlaybookModel,
        taskService: any TaskServiceProtocol,
        weeklyPlanService: any WeeklyPlanServiceProtocol
    ) {
        self.playbook = playbook
        self.taskService = taskService
        self.weeklyPlanService = weeklyPlanService
    }

    // MARK: - Load Data

    /// Loads last week's status and all tasks. Called on appear.
    /// If there are no incomplete Now tasks, automatically skips to Step 2 (Select).
    func loadData() {
        isLoading = true
        error = nil

        Task {
            defer { isLoading = false }

            do {
                async let tasksResult = taskService.fetchTasks(
                    playbookId: playbook.id,
                    lane: nil,
                    updatedSince: nil
                )
                async let statusResult = weeklyPlanService.getWeeklyStatus(
                    playbookId: playbook.id
                )

                allTasks = try await tasksResult

                // Weekly status may 404 if no cycle exists yet — that's fine.
                do {
                    lastWeekCycle = try await statusResult
                } catch let error as WeeklyPlanError where error == .notFound {
                    lastWeekCycle = nil
                }

                // Initialize dispositions for all incomplete Now tasks.
                for task in incompleteTasks {
                    dispositions[task.id] = .keepInNow
                }

                // Skip review if no incomplete tasks.
                if shouldSkipReview {
                    currentStep = .select
                }
            } catch let error as TaskError {
                mapTaskError(error)
            } catch let error as WeeklyPlanError {
                mapWeeklyPlanError(error)
            } catch {
                self.error = "Something went wrong. Please try again."
            }
        }
    }

    // MARK: - Step 1 Actions

    /// Sets the disposition for a specific incomplete task.
    ///
    /// - Parameters:
    ///   - taskId: The ID of the incomplete task.
    ///   - disposition: How to handle the task (keep, move to next, move to later).
    func setDisposition(taskId: String, _ disposition: TaskDisposition) {
        dispositions[taskId] = disposition
    }

    /// Applies all dispositions (moves tasks as chosen), then advances to Step 2.
    ///
    /// Tasks with `.keepInNow` are left in place. Tasks with `.moveToNext` or
    /// `.moveToLater` are moved via the TaskService.
    func applyDispositionsAndAdvance() {
        isSubmitting = true
        error = nil

        Task {
            defer { isSubmitting = false }

            do {
                for (taskId, disposition) in dispositions {
                    let targetLane: TaskLane? = switch disposition {
                    case .keepInNow:   nil
                    case .moveToNext:  .next
                    case .moveToLater: .later
                    }

                    guard let lane = targetLane else { continue }

                    let dto = UpdateTaskDTO(
                        title: nil,
                        detail: nil,
                        lane: lane.rawValue,
                        estimatedMinutes: nil,
                        status: nil,
                        orderIndex: nil
                    )
                    let updated = try await taskService.updateTask(id: taskId, dto: dto)

                    if let index = allTasks.firstIndex(where: { $0.id == taskId }) {
                        allTasks[index].lane = updated.lane
                        allTasks[index].orderIndex = updated.orderIndex
                    }
                }

                currentStep = .select
            } catch let error as TaskError {
                mapTaskError(error)
            } catch {
                self.error = "Failed to apply changes. Please try again."
            }
        }
    }

    // MARK: - Step 2 Actions

    /// Toggles selection of a Next lane task.
    ///
    /// - Parameter taskId: The ID of the task to toggle.
    func toggleTaskSelection(_ taskId: String) {
        if selectedTaskIds.contains(taskId) {
            selectedTaskIds.remove(taskId)
        } else {
            selectedTaskIds.insert(taskId)
        }
    }

    /// Returns whether a specific task is currently selected.
    func isTaskSelected(_ taskId: String) -> Bool {
        selectedTaskIds.contains(taskId)
    }

    /// Creates the weekly plan with the selected task IDs, then advances to Step 3.
    func createPlanAndAdvance() {
        guard canCreatePlan else { return }

        isSubmitting = true
        error = nil

        Task {
            defer { isSubmitting = false }

            do {
                let taskIds = Array(selectedTaskIds)
                let cycle = try await weeklyPlanService.createWeeklyPlan(
                    playbookId: playbook.id,
                    taskIds: taskIds
                )
                newWeeklyCycle = cycle
                currentStep = .confirm
            } catch let error as WeeklyPlanError {
                mapWeeklyPlanError(error)
            } catch {
                self.error = "Failed to create plan. Please try again."
            }
        }
    }

    // MARK: - Navigation

    /// Navigates back to the previous step if allowed.
    func goBack() {
        guard canGoBack else { return }
        if currentStep == .select {
            currentStep = .review
        }
    }

    // MARK: - Private — Error Mapping

    private func mapTaskError(_ error: TaskError) {
        switch error {
        case .notFound:
            self.error = "Task not found."
        case .networkError:
            self.error = "Network error. Please check your connection."
        case .serverError:
            self.error = "Something went wrong. Please try again."
        }
    }

    private func mapWeeklyPlanError(_ error: WeeklyPlanError) {
        switch error {
        case .notFound:
            self.error = "Weekly plan not found."
        case .networkError:
            self.error = "Network error. Please check your connection."
        case .serverError:
            self.error = "Something went wrong. Please try again."
        }
    }
}
