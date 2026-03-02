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

    // MARK: - Navigation State

    @State private var showSections = false
    @State private var showWeeklyPlan = false
    @State private var showSyncError = false

    // MARK: - Reorder State

    @State private var draggingTaskId: String? = nil
    @State private var dragYOffset: CGFloat = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let monitor = vm.syncEngine?.networkMonitor {
                    OfflineBannerView(networkMonitor: monitor)
                }

                LaneSegmentedControl(
                    selectedLane: vm.selectedLane,
                    counts: vm.taskCounts,
                    onSelect: { vm.selectLane($0) }
                )

                if let error = vm.error {
                    ErrorBannerView(message: error)
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
            ToolbarItem(placement: .topBarLeading) {
                syncIndicator
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showWeeklyPlan = true
                    } label: {
                        Label("Weekly Plan", systemImage: "calendar")
                    }

                    Button {
                        showSections = true
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
        .alert("Sync Error", isPresented: $showSyncError) {
            Button("Retry") { vm.retrySync() }
            Button("Dismiss", role: .cancel) {}
        } message: {
            Text(vm.syncErrorMessage ?? "An error occurred while syncing.")
        }
        .navigationDestination(isPresented: $showSections) {
            SectionsListView(vm: SectionsViewModel(
                playbook: vm.playbook,
                sectionService: vm.sectionService
            ))
        }
        .sheet(item: $vm.selectedTask) { task in
            TaskDetailSheet(
                vm: TaskDetailViewModel(
                    task: task,
                    taskService: vm.taskService,
                    onComplete: { id in
                        vm.completeTask(id: id)
                        vm.clearSelectedTask()
                    },
                    onDelete: { id in
                        vm.allTasks.removeAll { $0.id == id }
                        vm.clearSelectedTask()
                    }
                )
            )
        }
        .fullScreenCover(isPresented: $showWeeklyPlan) {
            vm.loadTasks()
        } content: {
            WeeklyPlanFlowView(
                vm: WeeklyPlanViewModel(
                    playbook: vm.playbook,
                    taskService: vm.taskService,
                    weeklyPlanService: vm.weeklyPlanService
                )
            )
        }
    }

    // MARK: - Lane Content

    @ViewBuilder
    private var laneContent: some View {
        if vm.isLoading && vm.allTasks.isEmpty {
            SkeletonList(rowCount: 3)
        } else if vm.isEmpty {
            if vm.selectedLane == .now && vm.showCelebration {
                CelebrationView()
            } else {
                EmptyLaneView(lane: vm.selectedLane, message: vm.emptyStateMessage)
            }
        } else {
            taskList
        }
    }

    // MARK: - Task List

    /// Estimated height of a task card including spacing, used for reorder position calculations.
    private let cardHeight: CGFloat = 80

    private var taskList: some View {
        let tasks = vm.tasksInCurrentLane

        return LazyVStack(spacing: 12) {
            ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                let isDragging = draggingTaskId == task.id
                let shiftOffset = reorderShiftOffset(for: index, in: tasks)

                TaskCardRow(
                    task: task,
                    showCheckbox: vm.selectedLane != .later,
                    currentLane: vm.selectedLane,
                    isDragReordering: draggingTaskId != nil,
                    syncState: vm.taskSyncState(for: task.id),
                    onTap: { vm.selectTask(task) },
                    onComplete: { vm.completeTask(id: task.id) },
                    onMove: { lane in vm.moveTask(id: task.id, toLane: lane) },
                    onRetrySync: { vm.retryTaskSync(for: task.id) }
                )
                .scaleEffect(isDragging ? 1.02 : 1.0)
                .shadow(
                    color: isDragging ? .black.opacity(0.3) : .clear,
                    radius: isDragging ? 12 : 0,
                    y: isDragging ? 4 : 0
                )
                .offset(y: isDragging ? dragYOffset : shiftOffset)
                .zIndex(isDragging ? 1 : 0)
                .motionSafe(.spring(response: 0.3, dampingFraction: 0.7))
                .gesture(reorderGesture(for: task.id, at: index, count: tasks.count))
                .accessibilityAction(named: "Move up") { vm.moveTaskUp(id: task.id) }
                .accessibilityAction(named: "Move down") { vm.moveTaskDown(id: task.id) }
            }

            AddTaskButton(lane: vm.selectedLane)
                .padding(.top, 4)
        }
    }

    // MARK: - Reorder Gesture

    /// Builds a long-press-then-drag gesture for initiating reorder on a specific card.
    private func reorderGesture(for taskId: String, at sourceIndex: Int, count: Int) -> some Gesture {
        LongPressGesture(minimumDuration: 0.4)
            .sequenced(before: DragGesture())
            .onChanged { value in
                switch value {
                case .first(true):
                    // Long press recognized — lift the card.
                    if draggingTaskId == nil {
                        draggingTaskId = taskId
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    }
                case .second(true, let drag):
                    // Dragging after long press.
                    if let drag {
                        dragYOffset = drag.translation.height
                    }
                default:
                    break
                }
            }
            .onEnded { _ in
                guard draggingTaskId == taskId else { return }

                // Calculate target index from drag offset.
                let rawTarget = sourceIndex + Int(round(dragYOffset / cardHeight))
                let targetIndex = max(0, min(rawTarget, count - 1))

                // Build reordered IDs.
                var ids = vm.tasksInCurrentLane.map(\.id)
                let movedId = ids.remove(at: sourceIndex)
                ids.insert(movedId, at: targetIndex)

                vm.reorderTasks(ids: ids)

                // Drop haptic.
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()

                // Reset state.
                withAnimation(UIAccessibility.isReduceMotionEnabled ? nil : .spring(response: 0.3, dampingFraction: 0.8)) {
                    draggingTaskId = nil
                    dragYOffset = 0
                }
            }
    }

    // MARK: - Reorder Shift Calculation

    /// Calculates the vertical offset for non-dragged cards to make room for the dragged card.
    private func reorderShiftOffset(for index: Int, in tasks: [TaskModel]) -> CGFloat {
        guard let draggingId = draggingTaskId,
              let sourceIndex = tasks.firstIndex(where: { $0.id == draggingId }) else {
            return 0
        }

        let rawTarget = sourceIndex + Int(round(dragYOffset / cardHeight))
        let targetIndex = max(0, min(rawTarget, tasks.count - 1))

        // Cards between source and target need to shift.
        if sourceIndex < targetIndex {
            // Dragging down — cards in between shift up.
            if index > sourceIndex && index <= targetIndex {
                return -cardHeight
            }
        } else if sourceIndex > targetIndex {
            // Dragging up — cards in between shift down.
            if index >= targetIndex && index < sourceIndex {
                return cardHeight
            }
        }

        return 0
    }

    // MARK: - Sync Indicator

    @ViewBuilder
    private var syncIndicator: some View {
        let dot = SyncStatusDotView(status: vm.syncStatusValue)
            .accessibilityLabel("Sync status: \(SyncStatusDotView(status: vm.syncStatusValue).statusLabel)")

        if case .error = vm.syncStatusValue {
            Button { showSyncError = true } label: { dot }
                .accessibilityHint("Tap to see error details and retry")
        } else {
            dot
        }
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
        .motionSafe(.spring(duration: 0.6, bounce: 0.2))
    }
}

// MARK: - Task Card Row

/// A single task card with optional checkbox, title, time estimate pill, and swipe gestures.
///
/// Swipe gestures:
/// - **Swipe right**: Green reveal background; releasing past threshold completes the task.
/// - **Swipe left**: Reveals lane-move buttons for valid destination lanes.
private struct TaskCardRow: View {

    let task: TaskModel
    let showCheckbox: Bool
    let currentLane: TaskLane
    let isDragReordering: Bool
    var syncState: EntitySyncState? = nil
    let onTap: () -> Void
    let onComplete: () -> Void
    let onMove: (TaskLane) -> Void
    var onRetrySync: (() -> Void)? = nil

    // MARK: - Completion Animation State

    @State private var isCompleting = false
    @State private var isSliding = false
    @State private var completionTask: Task<Void, Never>?

    // MARK: - Swipe State

    @State private var dragOffset: CGFloat = 0
    @State private var swipeDirection: SwipeDirection? = nil
    @State private var hasTriggeredHaptic = false

    private enum SwipeDirection {
        case left, right
    }

    private enum SwipeConstants {
        static let completeThreshold: CGFloat = 120
        static let maxRightSwipe: CGFloat = 160
        static let laneButtonRevealWidth: CGFloat = 140
        static let directionLockThreshold: CGFloat = 10
    }

    private var moveDestinations: [TaskLane] {
        TaskLane.allCases.filter { $0 != currentLane }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .leading) {
            swipeBackgroundLayer

            cardContent
                .offset(x: isSliding ? -500 : dragOffset)
                .opacity(isSliding ? 0 : 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: .theme.radiusLg))
        .simultaneousGesture(dragGesture)
        .onDisappear { completionTask?.cancel() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(task.title), \(task.estimatedMinutes) minutes"
            + (showCheckbox ? ", double tap to complete" : "")
        )
        .accessibilityHint("Tap for details")
        .accessibilityAction(named: "Complete task") { onComplete() }
        .accessibilityAction(named: "Move to \(moveDestinations.first?.rawValue ?? "")") {
            if let dest = moveDestinations.first { onMove(dest) }
        }
        .accessibilityAction(named: "Move to \(moveDestinations.last?.rawValue ?? "")") {
            if let dest = moveDestinations.last, moveDestinations.count > 1 { onMove(dest) }
        }
    }

    // MARK: - Card Content

    private var cardContent: some View {
        Button {
            if dragOffset != 0 {
                withAnimation(UIAccessibility.isReduceMotionEnabled ? nil : .spring(response: 0.3, dampingFraction: 0.8)) {
                    dragOffset = 0
                }
                return
            }
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
                        .strikethrough(isCompleting, color: Color.theme.mutedForeground)
                        .opacity(isCompleting ? 0.5 : 1.0)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .motionSafe(.easeInOut(duration: 0.2))

                    if let detail = task.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.theme.caption)
                            .foregroundStyle(Color.theme.mutedForeground)
                            .opacity(isCompleting ? 0.3 : 1.0)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if let syncState {
                    syncIndicator(for: syncState)
                }

                TimeEstimatePill(minutes: task.estimatedMinutes)
            }
            .padding(16)
            .cardStyle()
        }
        .buttonStyle(.pressable)
    }

    // MARK: - Sync Indicator

    @ViewBuilder
    private func syncIndicator(for state: EntitySyncState) -> some View {
        switch state {
        case .pending, .inFlight:
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 12))
                .foregroundStyle(Color.theme.mutedForeground.opacity(0.6))
                .accessibilityLabel("Syncing")
                .accessibilityHint("This change is waiting to sync")

        case .failed:
            Button {
                onRetrySync?()
            } label: {
                Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.theme.destructive.opacity(0.8))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Sync failed")
            .accessibilityHint("Tap to retry syncing this change")
        }
    }

    // MARK: - Checkbox

    private var checkboxButton: some View {
        Button {
            guard !isCompleting else { return }
            beginCompletionAnimation()
        } label: {
            ZStack {
                Circle()
                    .stroke(
                        isCompleting ? Color.theme.accent : Color.theme.mutedForeground,
                        lineWidth: 1.5
                    )
                    .frame(width: 24, height: 24)

                if isCompleting {
                    Circle()
                        .fill(Color.theme.accent)
                        .frame(width: 24, height: 24)

                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.theme.background)
                }
            }
            .motionSafe(.easeInOut(duration: 0.15))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isCompleting ? "Completed" : "Complete task")
    }

    // MARK: - Completion Animation

    /// Starts the phased completion animation: checkbox fill + strikethrough → pause → slide out.
    ///
    /// With Reduce Motion enabled, skips all animation and completes immediately.
    private func beginCompletionAnimation() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        if UIAccessibility.isReduceMotionEnabled {
            onComplete()
            return
        }

        withAnimation(.easeInOut(duration: 0.15)) {
            isCompleting = true
        }

        completionTask = Task { @MainActor in
            // Phase 1: 1000ms pause — user sees the completed state.
            try? await Task.sleep(for: .seconds(1.0))
            guard !Task.isCancelled else { return }

            // Phase 2: 500ms slide left + fade out.
            withAnimation(.easeIn(duration: 0.5)) {
                isSliding = true
            }

            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { return }

            // Phase 3: Fire the completion callback.
            onComplete()
        }
    }

    // MARK: - Swipe Background

    @ViewBuilder
    private var swipeBackgroundLayer: some View {
        if dragOffset > 0 {
            completeRevealBackground
        } else if dragOffset < 0 {
            laneButtonsBackground
        }
    }

    private var completeRevealBackground: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.black)
                .padding(.leading, 20)
                .scaleEffect(dragOffset >= SwipeConstants.completeThreshold ? 1.2 : 1.0)
                .motionSafe(.spring(response: 0.3, dampingFraction: 0.7))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.theme.accent)
        .clipShape(RoundedRectangle(cornerRadius: .theme.radiusLg))
    }

    private var laneButtonsBackground: some View {
        HStack(spacing: 0) {
            Spacer()

            ForEach(moveDestinations, id: \.self) { lane in
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    onMove(lane)
                    withAnimation(UIAccessibility.isReduceMotionEnabled ? nil : .spring(response: 0.3, dampingFraction: 0.8)) {
                        dragOffset = 0
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: laneIcon(for: lane))
                            .font(.system(size: 18, weight: .semibold))
                        Text(lane.rawValue)
                            .font(.theme.badge)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(Color.theme.primaryForeground)
                    .frame(width: SwipeConstants.laneButtonRevealWidth / CGFloat(moveDestinations.count))
                    .frame(maxHeight: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.theme.primary)
        .clipShape(RoundedRectangle(cornerRadius: .theme.radiusLg))
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard !isDragReordering else { return }
                let horizontal = value.translation.width

                if swipeDirection == nil && abs(horizontal) > SwipeConstants.directionLockThreshold {
                    swipeDirection = horizontal > 0 ? .right : .left
                }

                guard let direction = swipeDirection else { return }

                switch direction {
                case .right:
                    dragOffset = min(max(horizontal, 0), SwipeConstants.maxRightSwipe)

                    if dragOffset >= SwipeConstants.completeThreshold && !hasTriggeredHaptic {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        hasTriggeredHaptic = true
                    }

                    if dragOffset < SwipeConstants.completeThreshold {
                        hasTriggeredHaptic = false
                    }

                case .left:
                    dragOffset = max(horizontal, -SwipeConstants.laneButtonRevealWidth)
                }
            }
            .onEnded { _ in
                let direction = swipeDirection
                swipeDirection = nil
                hasTriggeredHaptic = false

                if direction == .right && dragOffset >= SwipeConstants.completeThreshold {
                    withAnimation(UIAccessibility.isReduceMotionEnabled ? nil : .easeOut(duration: 0.25)) {
                        dragOffset = 500
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        onComplete()
                    }
                } else if direction == .left && abs(dragOffset) > SwipeConstants.directionLockThreshold {
                    withAnimation(UIAccessibility.isReduceMotionEnabled ? nil : .spring(response: 0.3, dampingFraction: 0.8)) {
                        dragOffset = -SwipeConstants.laneButtonRevealWidth
                    }
                } else {
                    withAnimation(UIAccessibility.isReduceMotionEnabled ? nil : .spring(response: 0.3, dampingFraction: 0.8)) {
                        dragOffset = 0
                    }
                }
            }
    }

    // MARK: - Helpers

    private func laneIcon(for lane: TaskLane) -> String {
        switch lane {
        case .now: "bolt.fill"
        case .next: "arrow.right.circle.fill"
        case .later: "tray.fill"
        }
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
            .frame(minHeight: 56)
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

// MARK: - Preview

#Preview("With Tasks") {
    NavigationStack {
        PlaybookHomeView(vm: {
            let vm = PlaybookHomeViewModel(
                playbook: PlaybookModel(id: "pb-1", title: "Side Hustle App", phase: .proof),
                taskService: PreviewTaskService(),
                sectionService: PreviewSectionService(),
                weeklyPlanService: PreviewWeeklyPlanService()
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
            taskService: PreviewTaskService(),
            sectionService: PreviewSectionService(),
            weeklyPlanService: PreviewWeeklyPlanService()
        ))
    }
}

/// A no-op section service for SwiftUI previews.
private struct PreviewSectionService: SectionServiceProtocol {
    func fetchSections(playbookId: String, updatedSince: Date?) async throws -> [SectionModel] { [] }
    func updateSection(playbookId: String, sectionType: SectionType, content: String) async throws -> SectionModel {
        SectionModel(playbookId: playbookId, sectionType: sectionType, content: content)
    }
}

/// A no-op weekly plan service for SwiftUI previews.
private struct PreviewWeeklyPlanService: WeeklyPlanServiceProtocol {
    func getWeeklyStatus(playbookId: String) async throws -> WeeklyCycleModel {
        WeeklyCycleModel(playbookId: playbookId, weekStartDate: .now)
    }
    func createWeeklyPlan(playbookId: String, taskIds: [String]) async throws -> WeeklyCycleModel {
        WeeklyCycleModel(playbookId: playbookId, weekStartDate: .now, totalCount: taskIds.count)
    }
    func fetchWeeklyCycles(playbookId: String) async throws -> [WeeklyCycleModel] { [] }
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
