//
//  PlaybookListViewModel.swift
//  idea-pilot
//
//  ViewModel driving the Playbook List screen.
//  Handles loading, pull-to-refresh, create, archive, and filtering.
//

import Foundation

/// Drives the Playbook List screen with loading, create, archive, and filter states.
///
/// Uses `@Observable` for modern SwiftUI data flow. Since the project uses
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, this class runs on MainActor
/// by default — safe for driving UI.
@Observable
final class PlaybookListViewModel {

    // MARK: - List State

    var playbooks: [PlaybookModel] = []
    var isLoading = false
    var error: String?

    // MARK: - Create Sheet State

    var showCreateSheet = false
    var newPlaybookTitle = ""

    // MARK: - Filter State

    var showArchived = false

    // MARK: - Computed

    /// The playbooks to display, filtering out archived unless `showArchived` is true.
    var filteredPlaybooks: [PlaybookModel] {
        if showArchived {
            return playbooks
        }
        return playbooks.filter { !$0.isArchived }
    }

    /// True when there are no playbooks to display and we're not loading.
    var isEmpty: Bool {
        filteredPlaybooks.isEmpty && !isLoading
    }

    // MARK: - Dependencies

    private let playbookService: any PlaybookServiceProtocol

    // MARK: - Init

    /// Creates a PlaybookListViewModel.
    ///
    /// - Parameter playbookService: The service for playbook API calls and persistence.
    init(playbookService: any PlaybookServiceProtocol) {
        self.playbookService = playbookService
    }

    // MARK: - Actions

    /// Loads playbooks on appear. Fires an async Task internally.
    func loadPlaybooks() {
        error = nil
        isLoading = true

        Task {
            defer { isLoading = false }

            do {
                playbooks = try await playbookService.fetchPlaybooks(updatedSince: nil)
            } catch let error as PlaybookError {
                mapError(error)
            } catch {
                self.error = "Something went wrong. Please try again."
            }
        }
    }

    /// Refreshes playbooks for pull-to-refresh. Async so SwiftUI `.refreshable` can await it.
    func refresh() async {
        error = nil

        do {
            playbooks = try await playbookService.fetchPlaybooks(updatedSince: nil)
        } catch let error as PlaybookError {
            mapError(error)
        } catch {
            self.error = "Something went wrong. Please try again."
        }
    }

    /// Creates a new playbook with the current `newPlaybookTitle`.
    ///
    /// Validates the title is non-empty, calls the service, appends the result,
    /// then clears the title and dismisses the sheet.
    func createPlaybook() {
        let trimmed = newPlaybookTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        Task {
            do {
                let playbook = try await playbookService.createPlaybook(title: trimmed, description: nil)
                playbooks.append(playbook)
                newPlaybookTitle = ""
                showCreateSheet = false
            } catch let error as PlaybookError {
                mapError(error)
            } catch {
                self.error = "Failed to create playbook. Please try again."
            }
        }
    }

    /// Archives a playbook by ID, removing it from the list.
    func archivePlaybook(id: String) {
        Task {
            do {
                try await playbookService.archivePlaybook(id: id)
                if let index = playbooks.firstIndex(where: { $0.id == id }) {
                    playbooks[index].isArchived = true
                }
            } catch let error as PlaybookError {
                mapError(error)
            } catch {
                self.error = "Failed to archive playbook. Please try again."
            }
        }
    }

    /// Toggles the display of archived playbooks.
    func toggleShowArchived() {
        showArchived.toggle()
    }

    // MARK: - Private

    private func mapError(_ error: PlaybookError) {
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
