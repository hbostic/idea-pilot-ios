//
//  WeeklyPlanFlowView.swift
//  idea-pilot
//
//  Full-screen 3-step weekly planning ritual.
//  Review last week → Select this week's tasks → Confirm and go.
//

import SwiftUI

// MARK: - WeeklyPlanFlowView

/// Full-screen modal containing the 3-step weekly planning flow.
///
/// Presented from PlaybookHomeView's overflow menu. Each step is
/// driven by `WeeklyPlanViewModel` state. Dismissal mid-flow shows
/// an "Abandon?" confirmation dialog.
struct WeeklyPlanFlowView: View {

    @Bindable var vm: WeeklyPlanViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showAbandonConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                StepIndicator(
                    currentStep: vm.currentStep,
                    shouldSkipReview: vm.shouldSkipReview,
                    onTapBack: { vm.goBack() }
                )
                .padding(.top, 8)

                if vm.isLoading && vm.allTasks.isEmpty {
                    SkeletonList(rowCount: 3)
                        .padding(.top, 16)
                } else {
                    stepContent
                        .id(vm.currentStep)
                        .transition(.opacity)
                        .motionSafe(.easeInOut(duration: 0.2))
                }
            }
            .themeBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if vm.currentStep == .confirm {
                            dismiss()
                        } else {
                            showAbandonConfirmation = true
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.theme.mutedForeground)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
        .interactiveDismissDisabled(vm.currentStep != .confirm)
        .confirmationDialog(
            "Abandon weekly planning?",
            isPresented: $showAbandonConfirmation,
            titleVisibility: .visible
        ) {
            Button("Abandon", role: .destructive) { dismiss() }
            Button("Keep Planning", role: .cancel) {}
        }
        .task { vm.loadData() }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch vm.currentStep {
        case .review:
            ReviewStepView(vm: vm)
        case .select:
            SelectStepView(vm: vm)
        case .confirm:
            ConfirmStepView(vm: vm, onDismiss: { dismiss() })
        }
    }

}

// MARK: - Step Indicator

/// Three horizontal dots showing progress through the flow.
/// Active dot is primary-colored and larger. Past dots are tappable for back navigation.
private struct StepIndicator: View {

    let currentStep: WeeklyPlanStep
    let shouldSkipReview: Bool
    let onTapBack: () -> Void

    private var visibleSteps: [WeeklyPlanStep] {
        shouldSkipReview
            ? [.select, .confirm]
            : WeeklyPlanStep.allCases
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(visibleSteps, id: \.rawValue) { step in
                let state = dotState(for: step)

                Circle()
                    .fill(state.color)
                    .frame(width: state.size, height: state.size)
                    .onTapGesture {
                        if step.rawValue < currentStep.rawValue {
                            onTapBack()
                        }
                    }
                    .accessibilityLabel("Step \(step.title)")
                    .accessibilityAddTraits(step == currentStep ? .isSelected : [])
                    .accessibilityHint(
                        step.rawValue < currentStep.rawValue ? "Tap to go back" : ""
                    )
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Step \(currentStep.rawValue + 1) of \(visibleSteps.count): \(currentStep.title)")
    }

    private struct DotState {
        let color: Color
        let size: CGFloat
    }

    private func dotState(for step: WeeklyPlanStep) -> DotState {
        if step == currentStep {
            return DotState(color: Color.theme.primary, size: 10)
        } else if step.rawValue < currentStep.rawValue {
            return DotState(color: Color.theme.primary.opacity(0.5), size: 8)
        } else {
            return DotState(color: Color.theme.secondary, size: 8)
        }
    }
}

// MARK: - Step 1: Review

/// Shows last week's completion stats, completed tasks (collapsible),
/// and incomplete tasks with disposition options (Keep / Next / Later).
private struct ReviewStepView: View {

    @Bindable var vm: WeeklyPlanViewModel
    @State private var showCompleted = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Week")
                        .font(.theme.title)
                        .foregroundStyle(Color.theme.foreground)

                    if let cycle = vm.lastWeekCycle {
                        Text(Self.weekDateRange(from: cycle.weekStartDate))
                            .font(.theme.subheadline)
                            .foregroundStyle(Color.theme.mutedForeground)
                    }
                }

                // Progress ring + stats
                if let cycle = vm.lastWeekCycle {
                    progressSection(cycle: cycle)
                }

                // Error banner
                if let error = vm.error {
                    errorBanner(error)
                }

                // Completed tasks (collapsible)
                if !vm.completedTasks.isEmpty {
                    completedSection
                }

                // Incomplete tasks with dispositions
                if !vm.incompleteTasks.isEmpty {
                    incompleteSection
                }

                // Continue button
                PrimaryActionButton(
                    title: "Continue",
                    isLoading: vm.isSubmitting,
                    isEnabled: !vm.isSubmitting
                ) {
                    vm.applyDispositionsAndAdvance()
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Helpers

    /// Formats a week start date as a readable date range (e.g., "Jun 2 – Jun 8").
    static func weekDateRange(from start: Date) -> String {
        let end = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }

    // MARK: - Progress Section

    private func progressSection(cycle: WeeklyCycleModel) -> some View {
        HStack(spacing: 20) {
            ProgressRing(
                completed: cycle.completedCount,
                total: cycle.totalCount
            )
            .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(cycle.completedCount) of \(cycle.totalCount)")
                    .font(.theme.title2)
                    .foregroundStyle(Color.theme.foreground)

                Text("tasks completed")
                    .font(.theme.subheadline)
                    .foregroundStyle(Color.theme.mutedForeground)
            }

            Spacer()
        }
        .padding(16)
        .cardStyle()
    }

    // MARK: - Completed Tasks

    private var completedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showCompleted.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showCompleted ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))

                    Text("Completed (\(vm.completedTasks.count))")
                        .font(.theme.caption)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(Color.theme.mutedForeground)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showCompleted ? "Hide completed tasks" : "Show completed tasks")

            if showCompleted {
                VStack(spacing: 8) {
                    ForEach(vm.completedTasks, id: \.id) { task in
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.theme.accent)

                            Text(task.title)
                                .font(.theme.body)
                                .foregroundStyle(Color.theme.mutedForeground)
                                .strikethrough(color: Color.theme.mutedForeground)
                                .lineLimit(1)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .cardStyle()
                    }
                }
                .transition(.opacity)
            }
        }
    }

    // MARK: - Incomplete Tasks

    private var incompleteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("INCOMPLETE")
                .font(.theme.overline)
                .foregroundStyle(Color.theme.mutedForeground)
                .tracking(1.0)

            VStack(spacing: 8) {
                ForEach(vm.incompleteTasks, id: \.id) { task in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            Text(task.title)
                                .font(.theme.body)
                                .foregroundStyle(Color.theme.foreground)
                                .lineLimit(2)

                            Spacer()

                            TimeEstimatePill(minutes: task.estimatedMinutes)
                        }

                        DispositionPicker(
                            selection: Binding(
                                get: { vm.dispositions[task.id] ?? .keepInNow },
                                set: { vm.setDisposition(taskId: task.id, $0) }
                            )
                        )
                    }
                    .padding(16)
                    .cardStyle()
                }
            }
        }
    }
}

// MARK: - Step 2: Select

/// Shows Next lane tasks with multi-select checkboxes, running total,
/// and a soft warning when more than 5 tasks are selected.
private struct SelectStepView: View {

    @Bindable var vm: WeeklyPlanViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Plan This Week")
                        .font(.theme.title)
                        .foregroundStyle(Color.theme.foreground)

                    Text("Aim for 3-5 tasks that fit this week's capacity.")
                        .font(.theme.subheadline)
                        .foregroundStyle(Color.theme.mutedForeground)
                }

                // Running total
                runningTotal

                // Warning
                if vm.showAmbitiousWarning {
                    warningBanner
                }

                // Error banner
                if let error = vm.error {
                    errorBanner(error)
                }

                // Task list
                if vm.nextLaneTasks.isEmpty {
                    emptyNextState
                } else {
                    taskList
                }

                // Back button (if review wasn't skipped)
                if vm.canGoBack {
                    Button {
                        vm.goBack()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Back to Review")
                                .font(.theme.body)
                        }
                        .foregroundStyle(Color.theme.mutedForeground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Go back to review step")
                }

                // Plan Week button
                PrimaryActionButton(
                    title: "Plan Week",
                    isLoading: vm.isSubmitting,
                    isEnabled: vm.canCreatePlan
                ) {
                    vm.createPlanAndAdvance()
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Running Total

    private var runningTotal: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.theme.primary)

            Text("Selected: \(vm.selectedCount) tasks")
                .font(.theme.body)
                .foregroundStyle(Color.theme.foreground)

            if vm.totalEstimatedMinutes > 0 {
                Text("~\(formattedTime(vm.totalEstimatedMinutes))")
                    .font(.theme.bodyTabular)
                    .foregroundStyle(Color.theme.mutedForeground)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.theme.primary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: .theme.radiusMd))
        .overlay(
            RoundedRectangle(cornerRadius: .theme.radiusMd)
                .stroke(Color.theme.primary.opacity(0.2), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(vm.selectedCount) tasks selected, approximately \(formattedTime(vm.totalEstimatedMinutes))")
    }

    // MARK: - Warning Banner

    private var warningBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline)
            Text("That's ambitious! Consider focusing on fewer tasks.")
                .font(.theme.subheadline)
        }
        .foregroundStyle(Color.orange)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: .theme.radiusMd))
        .overlay(
            RoundedRectangle(cornerRadius: .theme.radiusMd)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .transition(.opacity)
        .motionSafe(.easeInOut(duration: 0.2))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Warning: That's ambitious. Consider focusing on fewer tasks.")
    }

    // MARK: - Task List

    private var taskList: some View {
        VStack(spacing: 8) {
            ForEach(vm.nextLaneTasks, id: \.id) { task in
                let isSelected = vm.isTaskSelected(task.id)

                Button {
                    vm.toggleTaskSelection(task.id)
                } label: {
                    HStack(spacing: 12) {
                        // Checkbox
                        ZStack {
                            Circle()
                                .stroke(
                                    isSelected ? Color.theme.primary : Color.theme.mutedForeground,
                                    lineWidth: 1.5
                                )
                                .frame(width: 24, height: 24)

                            if isSelected {
                                Circle()
                                    .fill(Color.theme.primary)
                                    .frame(width: 24, height: 24)

                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }

                        Text(task.title)
                            .font(.theme.body)
                            .foregroundStyle(Color.theme.foreground)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Spacer()

                        TimeEstimatePill(minutes: task.estimatedMinutes)
                    }
                    .padding(16)
                    .cardStyle()
                    .overlay(
                        RoundedRectangle(cornerRadius: .theme.radiusLg)
                            .stroke(
                                isSelected ? Color.theme.primary.opacity(0.3) : Color.clear,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("\(task.title), \(task.estimatedMinutes) minutes")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityHint(isSelected ? "Tap to deselect" : "Tap to select")
            }
        }
    }

    // MARK: - Empty State

    private var emptyNextState: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 40)

            Image(systemName: "arrow.right.circle")
                .font(.system(size: 48))
                .foregroundStyle(Color.theme.mutedForeground)

            Text("No tasks in Next. Add tasks to your Next lane first.")
                .font(.theme.subheadline)
                .foregroundStyle(Color.theme.mutedForeground)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Helpers

    private func formattedTime(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }
}

// MARK: - Step 3: Confirm

/// Shows a summary of the newly created weekly plan with a "Let's Go" dismissal button.
private struct ConfirmStepView: View {

    @Bindable var vm: WeeklyPlanViewModel
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 24)

                // Success icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.theme.accent)

                // Header
                VStack(spacing: 8) {
                    Text("Week Planned")
                        .font(.theme.title)
                        .foregroundStyle(Color.theme.foreground)

                    Text("\(vm.selectedTasks.count) tasks moved to Now")
                        .font(.theme.subheadline)
                        .foregroundStyle(Color.theme.mutedForeground)
                }

                // Task summary
                VStack(spacing: 8) {
                    ForEach(vm.selectedTasks, id: \.id) { task in
                        HStack(spacing: 12) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.theme.primary)

                            Text(task.title)
                                .font(.theme.body)
                                .foregroundStyle(Color.theme.foreground)
                                .lineLimit(1)

                            Spacer()

                            TimeEstimatePill(minutes: task.estimatedMinutes)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .cardStyle()
                    }
                }
                .padding(.top, 8)

                Spacer()
                    .frame(height: 16)

                // Let's Go button
                PrimaryActionButton(
                    title: "Let's Go",
                    isLoading: false,
                    isEnabled: true
                ) {
                    onDismiss()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Disposition Picker

/// A segmented selector for choosing how to handle an incomplete task:
/// Keep in Now, Move to Next, or Move to Later.
private struct DispositionPicker: View {

    @Binding var selection: TaskDisposition

    private struct Option {
        let disposition: TaskDisposition
        let label: String
    }

    private let options: [Option] = [
        Option(disposition: .keepInNow, label: "Keep"),
        Option(disposition: .moveToNext, label: "Next"),
        Option(disposition: .moveToLater, label: "Later"),
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.disposition) { option in
                let isSelected = selection == option.disposition

                Button {
                    selection = option.disposition
                } label: {
                    Text(option.label)
                        .font(.theme.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(
                            isSelected ? Color.white : Color.theme.mutedForeground
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            isSelected ? Color.theme.primary : Color.theme.secondary
                        )
                        .clipShape(RoundedRectangle(cornerRadius: .theme.radiusSm))
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Task disposition: \(selection.rawValue)")
        .accessibilityHint("Choose keep, next, or later")
    }
}

// MARK: - Progress Ring

/// A circular progress indicator showing completion as a colored arc.
private struct ProgressRing: View {

    let completed: Int
    let total: Int

    private var progress: Double {
        guard total > 0 else { return 0 }
        return min(Double(completed) / Double(total), 1.0)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.theme.secondary, lineWidth: 6)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.theme.primary,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .motionSafe(.easeOut(duration: 0.8))

            Text("\(completed)/\(total)")
                .font(.theme.captionTabular)
                .foregroundStyle(Color.theme.foreground)
        }
        .accessibilityLabel("\(completed) of \(total) tasks completed")
    }
}

// MARK: - Primary Action Button

/// A full-width primary action button used across all steps.
private struct PrimaryActionButton: View {

    let title: String
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(Color.theme.primaryForeground)
                } else {
                    Text(title)
                        .font(.theme.body)
                        .fontWeight(.semibold)
                }
            }
            .foregroundStyle(Color.theme.primaryForeground)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(isEnabled ? Color.theme.primary : Color.theme.muted)
            .clipShape(RoundedRectangle(cornerRadius: .theme.radiusMd))
            .shadow(
                color: isEnabled ? Color.theme.primary.opacity(0.4) : .clear,
                radius: 12, y: 4
            )
        }
        .buttonStyle(.pressable)
        .disabled(!isEnabled || isLoading)
        .accessibilityLabel(title)
        .accessibilityHint(isEnabled ? "" : "Not available yet")
    }
}

// MARK: - Error Banner (shared)

/// Inline error banner matching the PlaybookHomeView pattern.
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

// MARK: - Preview

#Preview("Review Step") {
    WeeklyPlanFlowView(
        vm: {
            let vm = WeeklyPlanViewModel(
                playbook: PlaybookModel(id: "pb-1", title: "Side Hustle App"),
                taskService: WeeklyPlanPreviewTaskService(),
                weeklyPlanService: WeeklyPlanPreviewService()
            )
            vm.lastWeekCycle = WeeklyCycleModel(
                playbookId: "pb-1",
                weekStartDate: Calendar.current.date(byAdding: .day, value: -7, to: .now)!,
                completedCount: 3,
                totalCount: 5
            )
            vm.allTasks = [
                TaskModel(id: "t-1", playbookId: "pb-1", title: "Incomplete task from last week", lane: .now, estimatedMinutes: 60, orderIndex: 0),
                TaskModel(id: "t-2", playbookId: "pb-1", title: "Another incomplete task", lane: .now, estimatedMinutes: 90, orderIndex: 1),
                TaskModel(id: "t-3", playbookId: "pb-1", title: "Completed task", lane: .now, status: .done, orderIndex: 2, completedAt: .now),
                TaskModel(id: "t-4", playbookId: "pb-1", title: "Next lane task 1", lane: .next, estimatedMinutes: 30, orderIndex: 0),
                TaskModel(id: "t-5", playbookId: "pb-1", title: "Next lane task 2", lane: .next, estimatedMinutes: 60, orderIndex: 1),
            ]
            vm.dispositions = ["t-1": .keepInNow, "t-2": .moveToNext]
            return vm
        }()
    )
}

#Preview("Select Step") {
    WeeklyPlanFlowView(
        vm: {
            let vm = WeeklyPlanViewModel(
                playbook: PlaybookModel(id: "pb-1", title: "Side Hustle App"),
                taskService: WeeklyPlanPreviewTaskService(),
                weeklyPlanService: WeeklyPlanPreviewService()
            )
            vm.currentStep = .select
            vm.allTasks = [
                TaskModel(id: "t-1", playbookId: "pb-1", title: "Research competitor pricing", lane: .next, estimatedMinutes: 90, orderIndex: 0),
                TaskModel(id: "t-2", playbookId: "pb-1", title: "Write landing page copy", lane: .next, estimatedMinutes: 60, orderIndex: 1),
                TaskModel(id: "t-3", playbookId: "pb-1", title: "Design logo variations", lane: .next, estimatedMinutes: 120, orderIndex: 2),
                TaskModel(id: "t-4", playbookId: "pb-1", title: "Set up CI/CD pipeline", lane: .next, estimatedMinutes: 180, orderIndex: 3),
            ]
            vm.selectedTaskIds = ["t-1", "t-2"]
            return vm
        }()
    )
}

#Preview("Confirm Step") {
    WeeklyPlanFlowView(
        vm: {
            let vm = WeeklyPlanViewModel(
                playbook: PlaybookModel(id: "pb-1", title: "Side Hustle App"),
                taskService: WeeklyPlanPreviewTaskService(),
                weeklyPlanService: WeeklyPlanPreviewService()
            )
            vm.currentStep = .confirm
            vm.allTasks = [
                TaskModel(id: "t-1", playbookId: "pb-1", title: "Research competitor pricing", lane: .next, estimatedMinutes: 90, orderIndex: 0),
                TaskModel(id: "t-2", playbookId: "pb-1", title: "Write landing page copy", lane: .next, estimatedMinutes: 60, orderIndex: 1),
                TaskModel(id: "t-3", playbookId: "pb-1", title: "Design logo variations", lane: .next, estimatedMinutes: 120, orderIndex: 2),
            ]
            vm.selectedTaskIds = ["t-1", "t-2", "t-3"]
            vm.newWeeklyCycle = WeeklyCycleModel(playbookId: "pb-1", weekStartDate: .now, totalCount: 3)
            return vm
        }()
    )
}

/// A no-op task service for WeeklyPlanFlowView previews.
private struct WeeklyPlanPreviewTaskService: TaskServiceProtocol {
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

/// A no-op weekly plan service for WeeklyPlanFlowView previews.
private struct WeeklyPlanPreviewService: WeeklyPlanServiceProtocol {
    func getWeeklyStatus(playbookId: String) async throws -> WeeklyCycleModel {
        WeeklyCycleModel(playbookId: playbookId, weekStartDate: .now, completedCount: 3, totalCount: 5)
    }
    func createWeeklyPlan(playbookId: String, taskIds: [String]) async throws -> WeeklyCycleModel {
        WeeklyCycleModel(playbookId: playbookId, weekStartDate: .now, totalCount: taskIds.count)
    }
    func fetchWeeklyCycles(playbookId: String) async throws -> [WeeklyCycleModel] { [] }
}
