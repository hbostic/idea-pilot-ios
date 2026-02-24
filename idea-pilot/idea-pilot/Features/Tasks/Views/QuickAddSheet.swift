//
//  QuickAddSheet.swift
//  idea-pilot
//
//  Half-sheet for rapid task capture. Auto-focuses the title field,
//  stays open after each add for multi-capture workflow.
//

import SwiftUI

/// A half-sheet overlay for quickly creating tasks.
///
/// Features:
/// - Auto-focused title field
/// - Playbook picker (Menu-based)
/// - Lane selector chips (NOW / NEXT / LATER)
/// - Time estimate chips (30 / 60 / 90 / 120m)
/// - "Add to {Lane}" button
/// - Brief green flash on success, form clears, sheet stays open
/// - Discard confirmation when dismissing with unsaved content
/// - Cmd+Enter keyboard shortcut for submission
struct QuickAddSheet: View {

    @Bindable var vm: QuickAddViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTitleFocused: Bool
    @State private var showDiscardConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    playbookPicker
                    titleField
                    laneSection
                    estimateSection
                    addButton
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if vm.hasUnsavedContent {
                            showDiscardConfirmation = true
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundStyle(Color.theme.mutedForeground)
                }
            }
            .themeBackground()
            .task {
                vm.loadPlaybooks()
                try? await Task.sleep(for: .milliseconds(300))
                isTitleFocused = true
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.theme.background)
        .interactiveDismissDisabled(vm.hasUnsavedContent)
        .confirmationDialog(
            "Discard task?",
            isPresented: $showDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) {
                vm.clearForm()
                dismiss()
            }
            Button("Keep Editing", role: .cancel) {}
        }
        .overlay { successFlashOverlay }
        .onKeyPress(.return, phases: .down) { keyPress in
            if keyPress.modifiers.contains(.command) && vm.canSubmit {
                vm.addTask()
                return .handled
            }
            return .ignored
        }
    }

    // MARK: - Playbook Picker

    @ViewBuilder
    private var playbookPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PLAYBOOK")
                .font(.theme.overline)
                .foregroundStyle(Color.theme.mutedForeground)
                .tracking(1.0)

            Menu {
                ForEach(vm.playbooks, id: \.id) { playbook in
                    Button(playbook.title) {
                        vm.selectedPlaybook = playbook
                    }
                }
            } label: {
                HStack {
                    Text(vm.selectedPlaybook?.title ?? "Select Playbook")
                        .font(.theme.bodyRegular)
                        .foregroundStyle(
                            vm.selectedPlaybook != nil
                                ? Color.theme.foreground
                                : Color.theme.mutedForeground
                        )
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.theme.mutedForeground)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.theme.secondary)
                .clipShape(RoundedRectangle(cornerRadius: .theme.radiusMd))
                .overlay(
                    RoundedRectangle(cornerRadius: .theme.radiusMd)
                        .stroke(Color.theme.input, lineWidth: 1)
                )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Playbook: \(vm.selectedPlaybook?.title ?? "none selected")")
    }

    // MARK: - Title Field

    @ViewBuilder
    private var titleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TASK")
                .font(.theme.overline)
                .foregroundStyle(Color.theme.mutedForeground)
                .tracking(1.0)

            TextField("What needs to happen?", text: $vm.title)
                .font(.theme.title3)
                .foregroundStyle(Color.theme.foreground)
                .textInputAutocapitalization(.sentences)
                .focused($isTitleFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.theme.secondary)
                .clipShape(RoundedRectangle(cornerRadius: .theme.radiusMd))
                .overlay(
                    RoundedRectangle(cornerRadius: .theme.radiusMd)
                        .stroke(Color.theme.input, lineWidth: 1)
                )
                .submitLabel(.done)
                .accessibilityLabel("Task title")
        }
    }

    // MARK: - Lane Section

    @ViewBuilder
    private var laneSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LANE")
                .font(.theme.overline)
                .foregroundStyle(Color.theme.mutedForeground)
                .tracking(1.0)

            LaneChipGroup(selected: $vm.selectedLane)
        }
    }

    // MARK: - Estimate Section

    @ViewBuilder
    private var estimateSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ESTIMATE")
                .font(.theme.overline)
                .foregroundStyle(Color.theme.mutedForeground)
                .tracking(1.0)

            TimeEstimatePickerRow(
                selected: $vm.estimatedMinutes,
                options: [30, 60, 90, 120]
            )
        }
    }

    // MARK: - Add Button

    @ViewBuilder
    private var addButton: some View {
        Button {
            vm.addTask()
            isTitleFocused = true
        } label: {
            Text(vm.addButtonTitle)
                .font(.theme.body)
                .fontWeight(.semibold)
                .foregroundStyle(Color.theme.primaryForeground)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(vm.canSubmit ? Color.theme.primary : Color.theme.muted)
                .clipShape(RoundedRectangle(cornerRadius: .theme.radiusMd))
                .shadow(
                    color: vm.canSubmit ? Color.theme.primary.opacity(0.4) : .clear,
                    radius: 12, y: 4
                )
        }
        .buttonStyle(.pressable)
        .disabled(!vm.canSubmit)
        .accessibilityLabel(vm.addButtonTitle)
        .accessibilityHint(vm.canSubmit ? "Creates a new task" : "Enter a title first")
    }

    // MARK: - Success Flash

    @ViewBuilder
    private var successFlashOverlay: some View {
        if vm.showSuccessFlash {
            Color.theme.accent.opacity(0.15)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }
}

// MARK: - Preview

#Preview {
    QuickAddSheet(
        vm: {
            let vm = QuickAddViewModel(
                taskService: QuickAddPreviewTaskService(),
                playbookService: QuickAddPreviewPlaybookService()
            )
            vm.playbooks = [PlaybookModel(id: "pb-1", title: "Side Project")]
            vm.selectedPlaybook = vm.playbooks.first
            return vm
        }()
    )
}

/// A no-op task service for QuickAddSheet previews.
private struct QuickAddPreviewTaskService: TaskServiceProtocol {
    nonisolated func fetchTasks(playbookId: String, lane: TaskLane?, updatedSince: Date?) async throws -> [TaskModel] { [] }
    nonisolated func createTask(playbookId: String, title: String, detail: String?, lane: TaskLane, estimatedMinutes: Int) async throws -> TaskModel {
        TaskModel(playbookId: playbookId, title: title, lane: lane, estimatedMinutes: estimatedMinutes)
    }
    nonisolated func updateTask(id: String, dto: UpdateTaskDTO) async throws -> TaskModel {
        TaskModel(playbookId: "pb-1", title: "Updated")
    }
    nonisolated func completeTask(id: String) async throws -> TaskModel {
        TaskModel(playbookId: "pb-1", title: "Done", status: .done, completedAt: .now)
    }
    nonisolated func reorderTasks(playbookId: String, lane: TaskLane, taskIds: [String]) async throws {}
    nonisolated func deleteTask(id: String) async throws {}
}

/// A no-op playbook service for QuickAddSheet previews.
private struct QuickAddPreviewPlaybookService: PlaybookServiceProtocol {
    nonisolated func fetchPlaybooks(updatedSince: Date?) async throws -> [PlaybookModel] { [] }
    nonisolated func createPlaybook(title: String, description: String?) async throws -> PlaybookModel {
        PlaybookModel(id: UUID().uuidString, title: title)
    }
    nonisolated func archivePlaybook(id: String) async throws {}
}
