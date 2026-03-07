//
//  PlaybookHomeViewModel.swift
//  idea-pilot
//
//  ViewModel for the Playbook Home screen — the core execution surface.
//  Manages lane selection, task filtering, and all task operations.
//

import Foundation

/// Drives the Playbook Home screen with lane filtering, task operations, and real-time counts.
///
/// Uses `@Observable` for modern SwiftUI data flow. Since the project uses
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, this class runs on MainActor
/// by default — safe for driving UI.
@Observable
final class PlaybookHomeViewModel {

    // MARK: - Playbook Context

    let playbook: PlaybookModel

    // MARK: - Task State

    var allTasks: [TaskModel] = []
    var isLoading = false
    var error: String?

    // MARK: - Lane State

    var selectedLane: TaskLane = .now

    // MARK: - Detail Sheet

    var selectedTask: TaskModel?

    // MARK: - Celebration

    /// True when the last Now-lane task was just completed, triggering the celebration view.
    var showCelebration = false

    // MARK: - Computed

    /// Tasks in the current lane that are still open, sorted by display order.
    var tasksInCurrentLane: [TaskModel] {
        allTasks
            .filter { $0.lane == selectedLane && $0.status == .open }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    /// Count of open tasks per lane, suitable for driving badge numbers.
    var taskCounts: [TaskLane: Int] {
        var counts: [TaskLane: Int] = [:]
        for lane in TaskLane.allCases {
            counts[lane] = allTasks.count { $0.lane == lane && $0.status == .open }
        }
        return counts
    }

    /// True when the current lane has no tasks to display and we're not loading.
    var isEmpty: Bool {
        tasksInCurrentLane.isEmpty && !isLoading
    }

    /// A contextual empty-state message for the currently selected lane.
    var emptyStateMessage: String {
        switch selectedLane {
        case .now:
            "No active tasks. Move a task to Now to get started."
        case .next:
            "Nothing queued up yet."
        case .later:
            "Your backlog is empty."
        }
    }

    // MARK: - Sync

    /// The current sync status, derived from the SyncEngine.
    /// Defaults to `.synced` when no engine is available.
    var syncStatusValue: SyncStatusValue {
        syncEngine?.status.value ?? .synced
    }

    /// The error message from the sync engine when status is `.error`.
    var syncErrorMessage: String? {
        if case .error(let message) = syncStatusValue { return message }
        return nil
    }

    /// Returns the sync state for a specific task, or `nil` if fully synced.
    ///
    /// Reads from `SyncEngine.mutationQueue.entityStates`, which is
    /// `@Observable`. SwiftUI views that call this will automatically
    /// re-render when the dictionary changes.
    func taskSyncState(for taskId: String) -> EntitySyncState? {
        syncEngine?.mutationQueue.entityStates[taskId]
    }

    /// Retries syncing a specific failed task by triggering a queue drain.
    func retryTaskSync(for taskId: String) {
        syncEngine?.triggerDrain()
    }

    // MARK: - Dependencies

    let taskService: any TaskServiceProtocol
    let sectionService: any SectionServiceProtocol
    let weeklyPlanService: any WeeklyPlanServiceProtocol
    let syncEngine: SyncEngine?

    // MARK: - Init

    /// Creates a PlaybookHomeViewModel.
    ///
    /// - Parameters:
    ///   - playbook: The playbook whose tasks are managed.
    ///   - taskService: The service for task API calls and persistence.
    ///   - sectionService: The service for section API calls and persistence.
    ///   - weeklyPlanService: The service for weekly plan API calls and persistence.
    ///   - syncEngine: The sync engine for displaying sync status. Pass `nil` when unavailable.
    init(playbook: PlaybookModel, taskService: any TaskServiceProtocol, sectionService: any SectionServiceProtocol, weeklyPlanService: any WeeklyPlanServiceProtocol, syncEngine: SyncEngine? = nil) {
        self.playbook = playbook
        self.taskService = taskService
        self.sectionService = sectionService
        self.weeklyPlanService = weeklyPlanService
        self.syncEngine = syncEngine
    }

    // MARK: - Actions

    /// Loads all tasks for this playbook on appear. Fires an async Task internally.
    ///
    /// Also persists this playbook as the last-viewed so the Now tab can restore it.
    func loadTasks() {
        NowTabViewModel.saveLastViewedPlaybookId(playbook.id)

        error = nil
        isLoading = true
        showCelebration = false

        Task {
            defer { isLoading = false }

            do {
                allTasks = try await taskService.fetchTasks(
                    playbookId: playbook.id,
                    lane: nil,
                    updatedSince: nil
                )
            } catch let error as TaskError {
                mapError(error)
            } catch {
                self.error = "Something went wrong. Please try again."
            }
        }
    }

    /// Refreshes tasks for pull-to-refresh. Async so SwiftUI `.refreshable` can await it.
    func refresh() async {
        error = nil
        showCelebration = false

        do {
            allTasks = try await taskService.fetchTasks(
                playbookId: playbook.id,
                lane: nil,
                updatedSince: nil
            )
        } catch let error as TaskError {
            mapError(error)
        } catch {
            self.error = "Something went wrong. Please try again."
        }
    }

    /// Switches the selected lane. Instant — no network call, just re-filters cached tasks.
    func selectLane(_ lane: TaskLane) {
        selectedLane = lane
        showCelebration = false
    }

    /// Marks a task as done. Updates the local list on success.
    /// Shows a celebration when the last Now-lane task is completed.
    func completeTask(id: String) {
        let wasLastNowTask = selectedLane == .now
            && allTasks.count(where: { $0.lane == .now && $0.status == .open }) == 1

        Task {
            do {
                let updated = try await taskService.completeTask(id: id)
                if let index = allTasks.firstIndex(where: { $0.id == id }) {
                    allTasks[index].status = updated.status
                    allTasks[index].completedAt = updated.completedAt
                }
                if wasLastNowTask {
                    showCelebration = true
                }
            } catch let error as TaskError {
                mapError(error)
            } catch {
                self.error = "Failed to complete task. Please try again."
            }
        }
    }

    /// Moves a task to a different lane. Updates the local list on success.
    func moveTask(id: String, toLane lane: TaskLane) {
        Task {
            do {
                let dto = UpdateTaskDTO(
                    title: nil,
                    detail: nil,
                    lane: lane.rawValue,
                    estimatedMinutes: nil,
                    status: nil,
                    orderIndex: nil
                )
                let updated = try await taskService.updateTask(id: id, dto: dto)
                if let index = allTasks.firstIndex(where: { $0.id == id }) {
                    allTasks[index].lane = updated.lane
                    allTasks[index].orderIndex = updated.orderIndex
                }
            } catch let error as TaskError {
                mapError(error)
            } catch {
                self.error = "Failed to move task. Please try again."
            }
        }
    }

    /// Reorders tasks within the current lane. Updates local order immediately, then syncs.
    func reorderTasks(ids: [String]) {
        // Update local order indices immediately for responsive UI.
        for (newIndex, taskId) in ids.enumerated() {
            if let index = allTasks.firstIndex(where: { $0.id == taskId }) {
                allTasks[index].orderIndex = newIndex
            }
        }

        Task {
            do {
                try await taskService.reorderTasks(
                    playbookId: playbook.id,
                    lane: selectedLane,
                    taskIds: ids
                )
            } catch let error as TaskError {
                mapError(error)
            } catch {
                self.error = "Failed to reorder tasks. Please try again."
            }
        }
    }

    /// Moves a task one position up (lower index) within the current lane.
    /// Used by VoiceOver accessibility actions.
    func moveTaskUp(id: String) {
        var ids = tasksInCurrentLane.map(\.id)
        guard let index = ids.firstIndex(of: id), index > 0 else { return }
        ids.swapAt(index, index - 1)
        reorderTasks(ids: ids)
    }

    /// Moves a task one position down (higher index) within the current lane.
    /// Used by VoiceOver accessibility actions.
    func moveTaskDown(id: String) {
        var ids = tasksInCurrentLane.map(\.id)
        guard let index = ids.firstIndex(of: id), index < ids.count - 1 else { return }
        ids.swapAt(index, index + 1)
        reorderTasks(ids: ids)
    }

    /// Selects a task for the detail half-sheet.
    func selectTask(_ task: TaskModel) {
        selectedTask = task
    }

    /// Clears the selected task, dismissing the detail sheet.
    func clearSelectedTask() {
        selectedTask = nil
    }

    /// Retries sync when the user taps the error indicator.
    func retrySync() {
        Task { await syncEngine?.onPullToRefresh() }
    }

    // MARK: - Private

    private func mapError(_ error: TaskError) {
        switch error {
        case .notFound:
            self.error = "Task not found."
        case .networkError:
            self.error = "Network error. Please check your connection."
        case .serverError:
            self.error = "Something went wrong. Please try again."
        }
    }
}
