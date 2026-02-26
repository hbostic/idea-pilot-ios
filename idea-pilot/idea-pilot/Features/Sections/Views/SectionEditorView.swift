//
//  SectionEditorView.swift
//  idea-pilot
//
//  Full-screen plain text editor for a playbook section.
//  Auto-saves with 1-second debounce, shows character/word count.
//

import SwiftUI

/// Full-screen plain text editor for a playbook section.
///
/// Features:
/// - Large TextEditor with placeholder
/// - Auto-save with 1-second debounce on content change
/// - Character and word count at bottom (subtle gray)
/// - Flush save on disappear to prevent data loss
struct SectionEditorView: View {

    @Bindable var vm: SectionsViewModel
    let section: SectionModel

    var body: some View {
        VStack(spacing: 0) {
            editorArea

            Divider()
                .background(Color.theme.border)

            wordCountBar
        }
        .themeBackground()
        .navigationTitle(section.sectionType.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.startEditing(section)
        }
        .onDisappear {
            vm.flushSave()
        }
    }

    // MARK: - Editor Area

    private var editorArea: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $vm.editorContent)
                .font(.theme.bodyRegular)
                .foregroundStyle(Color.theme.foreground)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .onChange(of: vm.editorContent) { _, _ in
                    vm.saveContent()
                }
                .accessibilityLabel("\(section.sectionType.displayName) content")

            if vm.editorContent.isEmpty {
                Text("Start writing your \(section.sectionType.displayName.lowercased())...")
                    .font(.theme.bodyRegular)
                    .foregroundStyle(Color.theme.mutedForeground)
                    .padding(.horizontal, 21)
                    .padding(.vertical, 20)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Word Count Bar

    private var wordCountBar: some View {
        HStack {
            Spacer()

            Text("\(vm.characterCount) characters")
                .font(.theme.caption)
                .foregroundStyle(Color.theme.mutedForeground)

            Text("  \u{00B7}  ")
                .foregroundStyle(Color.theme.mutedForeground)

            Text("\(vm.wordCount) words")
                .font(.theme.caption)
                .foregroundStyle(Color.theme.mutedForeground)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(vm.wordCount) words, \(vm.characterCount) characters")
    }
}

// MARK: - Preview

#Preview("With Content") {
    NavigationStack {
        SectionEditorView(
            vm: {
                let section = SectionModel(playbookId: "pb-1", sectionType: .vision, content: "Build the best productivity app for solopreneurs who need to ship fast and iterate weekly.")
                let vm = SectionsViewModel(
                    playbook: PlaybookModel(id: "pb-1", title: "Test Playbook"),
                    sectionService: SectionEditorPreviewService()
                )
                vm.sections = [section]
                vm.startEditing(section)
                return vm
            }(),
            section: SectionModel(playbookId: "pb-1", sectionType: .vision, content: "Build the best productivity app for solopreneurs who need to ship fast and iterate weekly.")
        )
    }
}

#Preview("Empty") {
    NavigationStack {
        SectionEditorView(
            vm: {
                let section = SectionModel(playbookId: "pb-1", sectionType: .build, content: "")
                let vm = SectionsViewModel(
                    playbook: PlaybookModel(id: "pb-1", title: "Test Playbook"),
                    sectionService: SectionEditorPreviewService()
                )
                vm.sections = [section]
                vm.startEditing(section)
                return vm
            }(),
            section: SectionModel(playbookId: "pb-1", sectionType: .build, content: "")
        )
    }
}

/// No-op section service for editor previews.
private struct SectionEditorPreviewService: SectionServiceProtocol {
    func fetchSections(playbookId: String, updatedSince: Date?) async throws -> [SectionModel] { [] }
    func updateSection(playbookId: String, sectionType: SectionType, content: String) async throws -> SectionModel {
        SectionModel(playbookId: playbookId, sectionType: sectionType, content: content)
    }
}
