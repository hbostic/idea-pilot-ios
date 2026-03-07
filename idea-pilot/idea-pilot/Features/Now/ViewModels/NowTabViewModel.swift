//
//  NowTabViewModel.swift
//  idea-pilot
//
//  ViewModel for the Now tab — resolves the last-viewed playbook
//  and provides it to PlaybookHomeView, or shows an empty state.
//

import Foundation

/// Drives the Now tab by resolving which playbook to display.
///
/// On load, fetches all playbooks and selects the last-viewed one
/// (persisted in UserDefaults). If no last-viewed playbook is stored
/// or it no longer exists, falls back to the first available playbook.
/// If no playbooks exist at all, exposes an empty state for the UI.
@Observable
final class NowTabViewModel {

    // MARK: - State

    var playbook: PlaybookModel?
    var isLoading = false
    var error: String?
    var showCreateSheet = false

    // MARK: - Create Sheet State

    var newPlaybookTitle = ""
    var newPlaybookDescription = ""

    // MARK: - Dependencies

    private let playbookService: any PlaybookServiceProtocol

    /// The UserDefaults key for the last-viewed playbook ID.
    static let lastViewedPlaybookKey = "lastViewedPlaybookId"

    // MARK: - Init

    /// Creates a NowTabViewModel.
    ///
    /// - Parameter playbookService: The service for fetching playbooks.
    init(playbookService: any PlaybookServiceProtocol) {
        self.playbookService = playbookService
    }

    // MARK: - Actions

    /// Loads playbooks and resolves the one to display on the Now tab.
    ///
    /// Resolution order:
    /// 1. Last-viewed playbook ID from UserDefaults (if it still exists and is not archived)
    /// 2. First non-archived playbook
    /// 3. `nil` (empty state)
    func loadPlaybook() {
        error = nil
        isLoading = true

        Task {
            defer { isLoading = false }

            do {
                let playbooks = try await playbookService.fetchPlaybooks(updatedSince: nil)
                let active = playbooks.filter { !$0.isArchived }
                resolvePlaybook(from: active)
            } catch {
                self.error = "Unable to load playbooks. Pull to refresh."
            }
        }
    }

    /// Refreshes playbooks. Async for `.refreshable`.
    func refresh() async {
        error = nil

        do {
            let playbooks = try await playbookService.fetchPlaybooks(updatedSince: nil)
            let active = playbooks.filter { !$0.isArchived }
            resolvePlaybook(from: active)
        } catch {
            self.error = "Unable to load playbooks. Pull to refresh."
        }
    }

    /// Creates a new playbook and sets it as the active Now playbook.
    func createPlaybook() {
        let trimmed = newPlaybookTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let desc = newPlaybookDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            do {
                let created = try await playbookService.createPlaybook(
                    title: trimmed,
                    description: desc.isEmpty ? nil : desc
                )
                playbook = created
                Self.saveLastViewedPlaybookId(created.id)
                newPlaybookTitle = ""
                newPlaybookDescription = ""
                showCreateSheet = false
            } catch {
                self.error = "Failed to create playbook. Please try again."
            }
        }
    }

    // MARK: - Last Viewed Persistence

    /// Saves the last-viewed playbook ID to UserDefaults.
    static func saveLastViewedPlaybookId(_ id: String) {
        UserDefaults.standard.set(id, forKey: lastViewedPlaybookKey)
    }

    /// Returns the last-viewed playbook ID, or `nil` if none is stored.
    static func lastViewedPlaybookId() -> String? {
        UserDefaults.standard.string(forKey: lastViewedPlaybookKey)
    }

    // MARK: - Private

    /// Resolves which playbook to display from a list of active playbooks.
    private func resolvePlaybook(from active: [PlaybookModel]) {
        if let lastId = Self.lastViewedPlaybookId(),
           let match = active.first(where: { $0.id == lastId }) {
            playbook = match
        } else if let first = active.first {
            playbook = first
            Self.saveLastViewedPlaybookId(first.id)
        } else {
            playbook = nil
        }
    }
}
