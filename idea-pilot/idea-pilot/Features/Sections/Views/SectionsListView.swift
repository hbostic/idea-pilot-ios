//
//  SectionsListView.swift
//  idea-pilot
//
//  Displays the 4 playbook sections (Vision, System, Build, Business Model)
//  as a list. Tapping a row navigates to the full-screen section editor.
//

import SwiftUI

/// Displays the 4 playbook sections as a list of card rows.
///
/// Each row shows the section name, a first-line content preview, and a chevron.
/// Tapping a row navigates to the full-screen section editor.
struct SectionsListView: View {

    @Bindable var vm: SectionsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let error = vm.error {
                    errorBanner(error)
                }

                if vm.isLoading && vm.sections.isEmpty {
                    loadingView
                } else {
                    sectionsList
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .refreshable { await vm.refresh() }
        .onAppear { vm.loadSections() }
        .themeBackground()
        .navigationTitle("Sections")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections List

    private var sectionsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(vm.orderedSections, id: \.compositeId) { section in
                NavigationLink {
                    SectionEditorView(vm: vm, section: section)
                } label: {
                    SectionRow(
                        sectionType: section.sectionType,
                        previewText: vm.previewText(for: section)
                    )
                }
                .buttonStyle(.pressable)
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 120)

            ProgressView()
                .tint(Color.theme.mutedForeground)

            Text("Loading sections...")
                .font(.theme.subheadline)
                .foregroundStyle(Color.theme.mutedForeground)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline)
            Text(message)
                .font(.theme.subheadline)
        }
        .foregroundStyle(Color.theme.destructive)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.theme.destructive.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: .theme.radiusMd))
        .overlay(
            RoundedRectangle(cornerRadius: .theme.radiusMd)
                .stroke(Color.theme.destructive.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
    }
}

// MARK: - Section Row

/// A single row in the sections list showing name, preview, and chevron.
private struct SectionRow: View {

    let sectionType: SectionType
    let previewText: String

    /// SF Symbol icon for each section type.
    private var iconName: String {
        switch sectionType {
        case .vision: "eye.fill"
        case .system: "gearshape.2.fill"
        case .build: "hammer.fill"
        case .businessModel: "dollarsign.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 20))
                .foregroundStyle(Color.theme.primary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(sectionType.displayName)
                    .font(.theme.body)
                    .foregroundStyle(Color.theme.foreground)

                Text(previewText)
                    .font(.theme.caption)
                    .foregroundStyle(Color.theme.mutedForeground)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.theme.mutedForeground)
        }
        .padding(16)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(sectionType.displayName) section")
        .accessibilityHint(previewText == "No content yet" ? "No content yet. Tap to edit." : "Tap to edit")
    }
}

// MARK: - Preview

#Preview("With Content") {
    NavigationStack {
        SectionsListView(vm: {
            let vm = SectionsViewModel(
                playbook: PlaybookModel(id: "pb-1", title: "Test Playbook"),
                sectionService: SectionsListPreviewService()
            )
            vm.sections = [
                SectionModel(playbookId: "pb-1", sectionType: .vision, content: "Build the best productivity app for solopreneurs"),
                SectionModel(playbookId: "pb-1", sectionType: .system, content: "Daily standup, weekly review, monthly retro"),
                SectionModel(playbookId: "pb-1", sectionType: .build, content: ""),
                SectionModel(playbookId: "pb-1", sectionType: .businessModel, content: "Freemium with $9.99/mo pro tier"),
            ]
            return vm
        }())
    }
}

#Preview("Loading") {
    NavigationStack {
        SectionsListView(vm: {
            let vm = SectionsViewModel(
                playbook: PlaybookModel(id: "pb-1", title: "Test Playbook"),
                sectionService: SectionsListPreviewService()
            )
            vm.isLoading = true
            return vm
        }())
    }
}

/// No-op section service for SwiftUI previews.
private struct SectionsListPreviewService: SectionServiceProtocol {
    func fetchSections(playbookId: String, updatedSince: Date?) async throws -> [SectionModel] { [] }
    func updateSection(playbookId: String, sectionType: SectionType, content: String) async throws -> SectionModel {
        SectionModel(playbookId: playbookId, sectionType: sectionType, content: content)
    }
}
