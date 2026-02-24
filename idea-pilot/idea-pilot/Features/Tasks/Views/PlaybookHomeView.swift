//
//  PlaybookHomeView.swift
//  idea-pilot
//
//  The primary execution surface for a playbook.
//  Segmented lane control (NOW/NEXT/LATER), task card list,
//  checkboxes, time estimate pills, and contextual empty states.
//

import SwiftUI

/// The Playbook Home screen — the core execution surface.
///
/// Features:
/// - Segmented lane control with animated pill indicator and count badges
/// - Task cards with checkbox (NOW/NEXT only), title, and time estimate
/// - Pull-to-refresh, lane crossfade animation
/// - Overflow menu for Weekly Plan / Sections (placeholders)
/// - Empty state messages per lane
struct PlaybookHomeView: View {

    @Bindable var vm: PlaybookHomeViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                LaneSegmentedControl(
                    selectedLane: vm.selectedLane,
                    counts: vm.taskCounts,
                    onSelect: { vm.selectLane($0) }
                )

                if let error = vm.error {
                    errorBanner(error)
                }

                laneContent
                    .id(vm.selectedLane)
                    .transition(.opacity)
                    .motionSafe(.easeInOut(duration: 0.15))
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .safeAreaPadding(.bottom, 72)
        .refreshable { await vm.refresh() }
        .onAppear { vm.loadTasks() }
        .themeBackground()
        .navigationTitle(vm.playbook.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        // Weekly Plan placeholder — Issue #28
                    } label: {
                        Label("Weekly Plan", systemImage: "calendar")
                    }

                    Button {
                        // Sections placeholder — Issue #25
                    } label: {
                        Label("Sections", systemImage: "doc.text")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Color.theme.mutedForeground)
                }
                .accessibilityLabel("More options")
            }
        }
        .sheet(item: $vm.selectedTask) { task in
            TaskDetailPlaceholder(task: task)
        }
    }

    // MARK: - Lane Content

    @ViewBuilder
    private var laneContent: some View {
        if vm.isLoading && vm.allTasks.isEmpty {
            loadingView
        } else if vm.isEmpty {
            EmptyLaneView(lane: vm.selectedLane, message: vm.emptyStateMessage)
        } else {
            taskList
        }
    }

    // MARK: - Task List

    private var taskList: some View {
        LazyVStack(spacing: 12) {
            ForEach(vm.tasksInCurrentLane, id: \.id) { task in
                TaskCardRow(
                    task: task,
                    showCheckbox: vm.selectedLane != .later,
                    onTap: { vm.selectTask(task) },
                    onComplete: { vm.completeTask(id: task.id) }
                )
            }

            AddTaskButton(lane: vm.selectedLane)
                .padding(.top, 4)
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 120)

            ProgressView()
                .tint(Color.theme.mutedForeground)

            Text("Loading tasks…")
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

// MARK: - Lane Segmented Control

/// An animated segmented control for lane selection with count badges.
///
/// Features a sliding white pill indicator that animates between lanes
/// with a spring animation, and optional count badges on each segment.
private struct LaneSegmentedControl: View {

    let selectedLane: TaskLane
    let counts: [TaskLane: Int]
    let onSelect: (TaskLane) -> Void

    @Namespace private var pillNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TaskLane.allCases, id: \.self) { lane in
                Button {
                    onSelect(lane)
                } label: {
                    HStack(spacing: 6) {
                        Text(lane.rawValue)
                            .font(.theme.caption)
                            .fontWeight(.semibold)

                        if let count = counts[lane], count > 0 {
                            Text("\(count)")
                                .font(.theme.badge)
                                .foregroundStyle(selectedLane == lane ? Color.theme.primary : Color.theme.mutedForeground)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    selectedLane == lane
                                        ? Color.theme.primary.opacity(0.2)
                                        : Color.theme.muted
                                )
                                .clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(selectedLane == lane ? Color.black : Color.theme.mutedForeground)
                    .background {
                        if selectedLane == lane {
                            RoundedRectangle(cornerRadius: .theme.radiusSm)
                                .fill(Color.white)
                                .matchedGeometryEffect(id: "pill", in: pillNamespace)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(lane.rawValue) lane, \(counts[lane] ?? 0) tasks")
                .accessibilityAddTraits(selectedLane == lane ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color.theme.secondary)
        .clipShape(RoundedRectangle(cornerRadius: .theme.radiusMd))
        .motionSafe(.spring(response: 0.3, dampingFraction: 0.8))
    }
}

// MARK: - Task Card Row

/// A single task card with optional checkbox, title, and time estimate pill.
private struct TaskCardRow: View {

    let task: TaskModel
    let showCheckbox: Bool
    let onTap: () -> Void
    let onComplete: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                if showCheckbox {
                    checkboxButton
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.theme.body)
                        .foregroundStyle(Color.theme.foreground)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let detail = task.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.theme.caption)
                            .foregroundStyle(Color.theme.mutedForeground)
                            .lineLimit(1)
                    }
                }

                Spacer()

                TimeEstimatePill(minutes: task.estimatedMinutes)
            }
            .padding(16)
            .cardStyle()
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(task.title), \(task.estimatedMinutes) minutes"
            + (showCheckbox ? ", double tap to complete" : "")
        )
        .accessibilityHint("Tap for details")
    }

    private var checkboxButton: some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            onComplete()
        } label: {
            Circle()
                .stroke(Color.theme.mutedForeground, lineWidth: 1.5)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Complete task")
    }
}

// MARK: - Add Task Button

/// A dashed-border button to add a new task to the current lane.
private struct AddTaskButton: View {

    let lane: TaskLane

    var body: some View {
        Button {
            // Quick Add placeholder — Issue #22
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))

                Text("Add Task to \(lane.rawValue)")
                    .font(.theme.body)
            }
            .foregroundStyle(Color.theme.mutedForeground)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: .theme.radiusLg))
            .overlay(
                RoundedRectangle(cornerRadius: .theme.radiusLg)
                    .strokeBorder(
                        Color.theme.mutedForeground.opacity(0.3),
                        style: StrokeStyle(lineWidth: 1.5, dash: [8, 6])
                    )
            )
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Add task to \(lane.rawValue) lane")
    }
}

// MARK: - Empty Lane View

/// Displayed when the current lane has no tasks.
private struct EmptyLaneView: View {

    let lane: TaskLane
    let message: String

    private var iconName: String {
        switch lane {
        case .now: "checklist"
        case .next: "arrow.right.circle"
        case .later: "tray"
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 80)

            Image(systemName: iconName)
                .font(.system(size: 48))
                .foregroundStyle(Color.theme.mutedForeground)

            Text(message)
                .font(.theme.subheadline)
                .foregroundStyle(Color.theme.mutedForeground)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Task Detail Placeholder

/// Placeholder for the task detail half-sheet until Issue #23 is implemented.
private struct TaskDetailPlaceholder: View {

    let task: TaskModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(task.title)
                    .font(.theme.title2)
                    .foregroundStyle(Color.theme.foreground)

                Text("Task detail coming soon")
                    .font(.theme.subheadline)
                    .foregroundStyle(Color.theme.mutedForeground)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .themeBackground()
            .navigationTitle("Task Detail")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.theme.background)
    }
}

// MARK: - Preview

#Preview("With Tasks") {
    NavigationStack {
        PlaybookHomeView(vm: {
            let vm = PlaybookHomeViewModel(
                playbook: PlaybookModel(id: "pb-1", title: "Side Hustle App", phase: .proof),
                taskService: PreviewTaskService()
            )
            vm.allTasks = [
                TaskModel(id: "t-1", playbookId: "pb-1", title: "Research competitors", lane: .now, estimatedMinutes: 90, orderIndex: 0),
                TaskModel(id: "t-2", playbookId: "pb-1", title: "Write landing page copy", lane: .now, estimatedMinutes: 60, orderIndex: 1),
                TaskModel(id: "t-3", playbookId: "pb-1", title: "Design logo variations for brand review", lane: .next, estimatedMinutes: 120, orderIndex: 0),
                TaskModel(id: "t-4", playbookId: "pb-1", title: "Set up CI/CD", lane: .later, estimatedMinutes: 180, orderIndex: 0),
            ]
            return vm
        }())
    }
}

#Preview("Empty") {
    NavigationStack {
        PlaybookHomeView(vm: PlaybookHomeViewModel(
            playbook: PlaybookModel(id: "pb-1", title: "Empty Playbook"),
            taskService: PreviewTaskService()
        ))
    }
}

/// A no-op task service for SwiftUI previews.
private struct PreviewTaskService: TaskServiceProtocol {
    func fetchTasks(playbookId: String, lane: TaskLane?, updatedSince: Date?) async throws -> [TaskModel] { [] }
    func createTask(playbookId: String, title: String, detail: String?, lane: TaskLane, estimatedMinutes: Int) async throws -> TaskModel {
        TaskModel(playbookId: playbookId, title: title, lane: lane, estimatedMinutes: estimatedMinutes)
    }
    func updateTask(id: String, dto: UpdateTaskDTO) async throws -> TaskModel {
        TaskModel(playbookId: "pb-1", title: "Updated")
    }
    func completeTask(id: String) async throws -> TaskModel {
        TaskModel(playbookId: "pb-1", title: "Done", status: .done, completedAt: .now)
    }
    func reorderTasks(playbookId: String, lane: TaskLane, taskIds: [String]) async throws {}
    func deleteTask(id: String) async throws {}
}
