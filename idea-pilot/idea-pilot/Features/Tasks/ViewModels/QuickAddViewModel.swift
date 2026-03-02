//
//  QuickAddViewModel.swift
//  idea-pilot
//
//  ViewModel for the Quick Add (Capture) sheet — rapid task creation.
//  Manages form state, validation, submission, and success feedback.
//

import Foundation

/// Drives the Quick Add sheet with form validation, playbook selection, and task creation.
///
/// Uses `@Observable` for modern SwiftUI data flow. Since the project uses
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, this class runs on MainActor
/// by default — safe for driving UI.
@Observable
final class QuickAddViewModel {

    // MARK: - Form State

    var title: String = ""
    var selectedLane: TaskLane = .later
    var estimatedMinutes: Int = 60
    var selectedPlaybook: PlaybookModel?

    // MARK: - UI State

    var showSuccessFlash: Bool = false
    var isSubmitting: Bool = false
    var error: String?

    // MARK: - Data

    var playbooks: [PlaybookModel] = []

    // MARK: - Computed

    /// Whether the trimmed title is non-empty.
    var isTitleValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Whether all conditions for submission are met.
    var canSubmit: Bool {
        isTitleValid && selectedPlaybook != nil && !isSubmitting
    }

    /// Dynamic button label reflecting the selected lane.
    var addButtonTitle: String {
        "Add to \(selectedLane.rawValue)"
    }

    /// Whether the form has content that would be lost on dismiss.
    var hasUnsavedContent: Bool {
        isTitleValid
    }

    // MARK: - Dependencies

    private let taskService: any TaskServiceProtocol
    private let playbookService: any PlaybookServiceProtocol

    // MARK: - Init

    /// Creates a QuickAddViewModel.
    ///
    /// - Parameters:
    ///   - taskService: The service for creating tasks.
    ///   - playbookService: The service for fetching available playbooks.
    init(taskService: any TaskServiceProtocol, playbookService: any PlaybookServiceProtocol) {
        self.taskService = taskService
        self.playbookService = playbookService
    }

    // MARK: - Actions

    /// Loads available playbooks and auto-selects the first non-archived one.
    func loadPlaybooks() {
        Task {
            do {
                let fetched = try await playbookService.fetchPlaybooks(updatedSince: nil)
                let active = fetched.filter { !$0.isArchived }
                playbooks = active
                if selectedPlaybook == nil {
                    selectedPlaybook = active.first
                }
            } catch {
                // Silently fail — the picker will show "Select Playbook" prompt.
            }
        }
    }

    /// Creates a task with the current form values.
    ///
    /// On success: clears title, resets lane to `.later` and estimate to 60,
    /// triggers the success flash, but preserves the selected playbook for
    /// rapid multi-capture.
    func addTask() {
        guard canSubmit, let playbook = selectedPlaybook else { return }

        isSubmitting = true
        error = nil

        Task {
            defer { isSubmitting = false }

            do {
                _ = try await taskService.createTask(
                    playbookId: playbook.id,
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    detail: nil,
                    lane: selectedLane,
                    estimatedMinutes: estimatedMinutes
                )

                // Reset form for next capture.
                title = ""
                selectedLane = .later
                estimatedMinutes = 60

                // Trigger success flash.
                showSuccessFlash = true
                Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    showSuccessFlash = false
                }
            } catch let error as TaskError {
                mapError(error)
            } catch {
                self.error = "Failed to add task. Please try again."
            }
        }
    }

    /// Resets all form fields to their defaults.
    func clearForm() {
        title = ""
        selectedLane = .later
        estimatedMinutes = 60
        error = nil
    }

    // MARK: - Private

    private func mapError(_ error: TaskError) {
        switch error {
        case .notFound:
            self.error = "Playbook not found."
        case .networkError:
            self.error = "Network error. Please check your connection."
        case .serverError:
            self.error = "Something went wrong. Please try again."
        }
    }
}
