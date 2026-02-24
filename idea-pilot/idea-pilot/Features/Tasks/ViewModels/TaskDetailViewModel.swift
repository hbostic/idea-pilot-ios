//
//  TaskDetailViewModel.swift
//  idea-pilot
//
//  ViewModel for the Task Detail half-sheet.
//  Manages inline editing, debounced notes saving, completion, and deletion.
//

import Foundation

/// Drives the Task Detail sheet with inline editing, debounced saves, and task lifecycle actions.
///
/// Uses `@Observable` for modern SwiftUI data flow. Since the project uses
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, this class runs on MainActor
/// by default — safe for driving UI.
@Observable
final class TaskDetailViewModel {

    // MARK: - Editable State

    var title: String
    var detail: String
    var selectedLane: TaskLane
    var estimatedMinutes: Int

    // MARK: - UI State

    var isSubmitting = false
    var showDeleteConfirmation = false
    var error: String?

    // MARK: - Computed

    /// Whether the task is still open.
    var isOpen: Bool { task.status == .open }

    /// Display label for the task status.
    var statusLabel: String { task.status.rawValue }

    /// Whether the estimate exceeds the recommended maximum.
    var showEstimateWarning: Bool { estimatedMinutes > 180 }

    // MARK: - Dependencies

    let task: TaskModel
    private let taskService: any TaskServiceProtocol
    private let onComplete: (String) -> Void
    private let onDelete: (String) -> Void

    /// Tracks the debounced detail-save task so it can be cancelled on new input.
    private var detailSaveTask: Task<Void, Never>?

    // MARK: - Init

    /// Creates a TaskDetailViewModel.
    ///
    /// - Parameters:
    ///   - task: The task to view/edit (shared reference type).
    ///   - taskService: The service for task API calls.
    ///   - onComplete: Called with the task ID after successful completion.
    ///   - onDelete: Called with the task ID after successful deletion.
    init(
        task: TaskModel,
        taskService: any TaskServiceProtocol,
        onComplete: @escaping (String) -> Void,
        onDelete: @escaping (String) -> Void
    ) {
        self.task = task
        self.taskService = taskService
        self.onComplete = onComplete
        self.onDelete = onDelete

        // Initialize editable state from task.
        self.title = task.title
        self.detail = task.detail ?? ""
        self.selectedLane = task.lane
        self.estimatedMinutes = task.estimatedMinutes
    }

    // MARK: - Actions

    /// Saves the title to the server. Called on field commit.
    func saveTitle() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            // Revert to current task title if empty.
            title = task.title
            return
        }

        task.title = trimmed
        title = trimmed

        Task {
            do {
                let dto = UpdateTaskDTO(title: trimmed, detail: nil, lane: nil, estimatedMinutes: nil, status: nil, orderIndex: nil)
                _ = try await taskService.updateTask(id: task.id, dto: dto)
            } catch let error as TaskError {
                mapError(error)
            } catch {
                self.error = "Failed to save title."
            }
        }
    }

    /// Saves a lane change immediately. Called when selection changes.
    func saveLane(_ lane: TaskLane) {
        selectedLane = lane
        task.lane = lane

        Task {
            do {
                let dto = UpdateTaskDTO(title: nil, detail: nil, lane: lane.rawValue, estimatedMinutes: nil, status: nil, orderIndex: nil)
                _ = try await taskService.updateTask(id: task.id, dto: dto)
            } catch let error as TaskError {
                mapError(error)
            } catch {
                self.error = "Failed to update lane."
            }
        }
    }

    /// Saves an estimate change immediately. Called when selection changes.
    func saveEstimate(_ minutes: Int) {
        estimatedMinutes = minutes
        task.estimatedMinutes = minutes

        Task {
            do {
                let dto = UpdateTaskDTO(title: nil, detail: nil, lane: nil, estimatedMinutes: minutes, status: nil, orderIndex: nil)
                _ = try await taskService.updateTask(id: task.id, dto: dto)
            } catch let error as TaskError {
                mapError(error)
            } catch {
                self.error = "Failed to update estimate."
            }
        }
    }

    /// Saves the detail/notes with a 1-second debounce.
    ///
    /// Updates the task model immediately for responsive UI,
    /// but delays the API call so rapid typing doesn't flood the server.
    func saveDetail() {
        task.detail = detail.isEmpty ? nil : detail

        detailSaveTask?.cancel()
        detailSaveTask = Task {
            try? await Task.sleep(for: .seconds(1))

            guard !Task.isCancelled else { return }

            do {
                let dto = UpdateTaskDTO(title: nil, detail: detail.isEmpty ? nil : detail, lane: nil, estimatedMinutes: nil, status: nil, orderIndex: nil)
                _ = try await taskService.updateTask(id: task.id, dto: dto)
            } catch let error as TaskError {
                mapError(error)
            } catch {
                self.error = "Failed to save notes."
            }
        }
    }

    /// Marks the task as done and notifies the parent.
    func completeTask() {
        guard isOpen else { return }

        task.status = .done
        task.completedAt = .now

        Task {
            do {
                _ = try await taskService.completeTask(id: task.id)
                onComplete(task.id)
            } catch let error as TaskError {
                // Rollback on failure.
                task.status = .open
                task.completedAt = nil
                mapError(error)
            } catch {
                task.status = .open
                task.completedAt = nil
                self.error = "Failed to complete task."
            }
        }
    }

    /// Deletes the task after confirmation and notifies the parent.
    func deleteTask() {
        isSubmitting = true

        Task {
            defer { isSubmitting = false }

            do {
                try await taskService.deleteTask(id: task.id)
                onDelete(task.id)
            } catch let error as TaskError {
                mapError(error)
            } catch {
                self.error = "Failed to delete task."
            }
        }
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
