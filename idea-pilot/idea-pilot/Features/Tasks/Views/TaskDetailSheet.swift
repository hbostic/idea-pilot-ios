//
//  TaskDetailSheet.swift
//  idea-pilot
//
//  Expandable half-sheet for viewing and editing task details.
//  Supports inline title editing, lane/estimate changes, notes with
//  debounced save, task completion, and deletion with confirmation.
//

import SwiftUI

/// An expandable half-sheet for viewing and editing a task.
///
/// Features:
/// - Status pill (OPEN blue / DONE green)
/// - Inline editable title
/// - Lane selector chips
/// - Estimate chips with >180m warning
/// - Notes textarea with debounced save
/// - Complete and Delete actions
struct TaskDetailSheet: View {

    @Bindable var vm: TaskDetailViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    statusPill
                    titleField
                    laneSection
                    estimateSection
                    notesSection

                    if let error = vm.error {
                        Text(error)
                            .font(.theme.caption)
                            .foregroundStyle(Color.theme.destructive)
                    }

                    actionButtons
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Task Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.theme.mutedForeground)
                }
            }
            .themeBackground()
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.theme.background)
        .confirmationDialog(
            "Delete this task?",
            isPresented: $vm.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                vm.deleteTask()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }

    // MARK: - Status Pill

    @ViewBuilder
    private var statusPill: some View {
        let isOpen = vm.isOpen
        let color = isOpen ? Color.theme.primary : Color.theme.accent

        Text(vm.statusLabel)
            .font(.theme.caption)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: .theme.radiusSm))
            .overlay(
                RoundedRectangle(cornerRadius: .theme.radiusSm)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
            .accessibilityLabel("Status: \(vm.statusLabel)")
    }

    // MARK: - Title Field

    @ViewBuilder
    private var titleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TITLE")
                .font(.theme.overline)
                .foregroundStyle(Color.theme.mutedForeground)
                .tracking(1.0)

            TextField("Task title", text: $vm.title)
                .font(.theme.title2)
                .foregroundStyle(Color.theme.foreground)
                .textInputAutocapitalization(.sentences)
                .onSubmit { vm.saveTitle() }
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
                .onChange(of: vm.selectedLane) { _, newLane in
                    vm.saveLane(newLane)
                }
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
                options: [30, 60, 90, 120, 180]
            )
            .onChange(of: vm.estimatedMinutes) { _, newMinutes in
                vm.saveEstimate(newMinutes)
            }

            if vm.showEstimateWarning {
                Text("Tasks over 3 hours are hard to complete. Consider breaking this into smaller tasks.")
                    .font(.theme.caption)
                    .foregroundStyle(Color.theme.destructive)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Notes Section

    @ViewBuilder
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NOTES")
                .font(.theme.overline)
                .foregroundStyle(Color.theme.mutedForeground)
                .tracking(1.0)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $vm.detail)
                    .font(.theme.bodyRegular)
                    .foregroundStyle(Color.theme.foreground)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .onChange(of: vm.detail) { _, _ in
                        vm.saveDetail()
                    }

                if vm.detail.isEmpty {
                    Text("Add notes or details...")
                        .font(.theme.bodyRegular)
                        .foregroundStyle(Color.theme.mutedForeground)
                        .padding(.horizontal, 17)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }
            .background(Color.theme.secondary)
            .clipShape(RoundedRectangle(cornerRadius: .theme.radiusMd))
            .overlay(
                RoundedRectangle(cornerRadius: .theme.radiusMd)
                    .stroke(Color.theme.input, lineWidth: 1)
            )
            .accessibilityLabel("Task notes")
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if vm.isOpen {
                completeButton
            }
            deleteButton
        }
    }

    @ViewBuilder
    private var completeButton: some View {
        Button {
            vm.completeTask()
        } label: {
            Text("Complete Task")
                .font(.theme.body)
                .fontWeight(.semibold)
                .foregroundStyle(Color.theme.accentForeground)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
                .background(Color.theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: .theme.radiusMd))
                .shadow(color: Color.theme.accent.opacity(0.4), radius: 12, y: 4)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Complete task")
    }

    @ViewBuilder
    private var deleteButton: some View {
        Button {
            vm.showDeleteConfirmation = true
        } label: {
            Text("Delete Task")
                .font(.theme.body)
                .fontWeight(.semibold)
                .foregroundStyle(Color.theme.destructive)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
                .background(Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: .theme.radiusMd))
                .overlay(
                    RoundedRectangle(cornerRadius: .theme.radiusMd)
                        .stroke(Color.theme.destructive.opacity(0.5), lineWidth: 1)
                )
        }
        .buttonStyle(.pressable)
        .disabled(vm.isSubmitting)
        .accessibilityLabel("Delete task")
        .accessibilityHint("Shows a confirmation dialog")
    }
}

// MARK: - Preview

#Preview {
    TaskDetailSheet(
        vm: TaskDetailViewModel(
            task: TaskModel(
                id: "t-1",
                playbookId: "pb-1",
                title: "Research competitors",
                detail: "Look at top 5 apps in the App Store",
                lane: .now,
                estimatedMinutes: 90,
                orderIndex: 0
            ),
            taskService: TaskDetailPreviewTaskService(),
            onComplete: { _ in },
            onDelete: { _ in }
        )
    )
}

/// A no-op task service for TaskDetailSheet previews.
private struct TaskDetailPreviewTaskService: TaskServiceProtocol {
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
