//
//  SectionsViewModel.swift
//  idea-pilot
//
//  ViewModel for the Sections list and editor screens.
//  Manages fetching all 4 sections, displaying them in a list,
//  and auto-saving editor content with a 1-second debounce.
//

import Foundation

/// Drives the Sections list and editor screens for a playbook.
///
/// Manages fetching all 4 sections, displaying them in a list,
/// and auto-saving editor content with a 1-second debounce.
@Observable
final class SectionsViewModel {

    // MARK: - List State

    var sections: [SectionModel] = []
    var isLoading = false
    var error: String?

    // MARK: - Editor State

    /// The content being edited in the section editor (bound to TextEditor).
    var editorContent: String = ""

    /// The section currently being edited, set when navigating to the editor.
    private(set) var editingSection: SectionModel?

    // MARK: - Computed

    /// Sections ordered by the fixed SectionType.allCases order.
    var orderedSections: [SectionModel] {
        let typeOrder = SectionType.allCases
        return typeOrder.compactMap { type in
            sections.first { $0.sectionType == type }
        }
    }

    /// Character count of the current editor content.
    var characterCount: Int {
        editorContent.count
    }

    /// Word count of the current editor content.
    var wordCount: Int {
        let trimmed = editorContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        return trimmed.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }

    /// First line of content for a section, used as preview text in the list.
    func previewText(for section: SectionModel) -> String {
        let firstLine = section.content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .first ?? ""
        return firstLine.isEmpty ? "No content yet" : firstLine
    }

    // MARK: - Dependencies

    let playbook: PlaybookModel
    private let sectionService: any SectionServiceProtocol

    /// Tracks the debounced save task so it can be cancelled on new input.
    private var saveTask: Task<Void, Never>?

    // MARK: - Init

    init(playbook: PlaybookModel, sectionService: any SectionServiceProtocol) {
        self.playbook = playbook
        self.sectionService = sectionService
    }

    // MARK: - List Actions

    /// Loads all sections for this playbook. Called on list appear.
    func loadSections() {
        error = nil
        isLoading = true

        Task {
            defer { isLoading = false }

            do {
                sections = try await sectionService.fetchSections(
                    playbookId: playbook.id,
                    updatedSince: nil
                )
            } catch let sectionError as SectionError {
                mapError(sectionError)
            } catch {
                self.error = "Something went wrong. Please try again."
            }
        }
    }

    /// Refreshes sections for pull-to-refresh.
    func refresh() async {
        error = nil

        do {
            sections = try await sectionService.fetchSections(
                playbookId: playbook.id,
                updatedSince: nil
            )
        } catch let sectionError as SectionError {
            mapError(sectionError)
        } catch {
            self.error = "Something went wrong. Please try again."
        }
    }

    // MARK: - Editor Actions

    /// Prepares the editor for a specific section. Called when navigating to editor.
    func startEditing(_ section: SectionModel) {
        editingSection = section
        editorContent = section.content
    }

    /// Saves the editor content with a 1-second debounce.
    /// Updates the model immediately for responsive UI.
    func saveContent() {
        guard let section = editingSection else { return }

        // Update model immediately for responsive UI.
        section.content = editorContent

        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }

            do {
                _ = try await sectionService.updateSection(
                    playbookId: section.playbookId,
                    sectionType: section.sectionType,
                    content: editorContent
                )
            } catch let sectionError as SectionError {
                mapError(sectionError)
            } catch {
                self.error = "Failed to save. Please try again."
            }
        }
    }

    /// Forces an immediate save (e.g., on disappear). Cancels pending debounce.
    func flushSave() {
        guard let section = editingSection else { return }

        saveTask?.cancel()

        // Only fire if content actually changed from what the model has.
        guard section.content != editorContent else { return }
        section.content = editorContent

        Task {
            do {
                _ = try await sectionService.updateSection(
                    playbookId: section.playbookId,
                    sectionType: section.sectionType,
                    content: editorContent
                )
            } catch {
                // Swallow on disappear — user is navigating away.
            }
        }
    }

    // MARK: - Private

    private func mapError(_ error: SectionError) {
        switch error {
        case .notFound:
            self.error = "Section not found."
        case .networkError:
            self.error = "Network error. Please check your connection."
        case .serverError:
            self.error = "Something went wrong. Please try again."
        }
    }
}
