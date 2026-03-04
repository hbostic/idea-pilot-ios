//
//  PlaybookListView.swift
//  idea-pilot
//
//  Playbook List screen matching the dark theme mockup.
//  Card rows with phase badges, create sheet, empty state, and swipe actions.
//

import SwiftUI

/// The Playbook List screen showing all user playbooks as dark-themed cards.
///
/// Features:
/// - Card rows with phase badge, task count, and chevron
/// - Pull-to-refresh
/// - Swipe-to-archive and long-press context menu
/// - Empty state with CTA
/// - Create sheet for new playbooks
struct PlaybookListView: View {

    @Bindable var vm: PlaybookListViewModel
    let taskService: any TaskServiceProtocol
    let sectionService: any SectionServiceProtocol
    let weeklyPlanService: any WeeklyPlanServiceProtocol
    let tokenManager: TokenManager
    let authService: any AuthServiceProtocol
    let syncEngine: SyncEngine?
    let onSignOut: () -> Void

    @State private var showSettings = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let monitor = syncEngine?.networkMonitor {
                    OfflineBannerView(networkMonitor: monitor)
                }

                if let error = vm.error {
                    ErrorBannerView(message: error)
                }

                if vm.isLoading && vm.playbooks.isEmpty {
                    SkeletonList(rowCount: 3, rowHeight: 88)
                } else if vm.isEmpty {
                    EmptyStateView(
                        icon: "square.stack.3d.up.slash",
                        title: "No playbooks yet",
                        message: "Create your first playbook to get started",
                        actionTitle: "New Playbook",
                        onAction: { vm.showCreateSheet = true }
                    )
                } else {
                    playbookList
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .safeAreaPadding(.bottom, 72)
        .refreshable { await vm.refresh() }
        .onAppear { vm.loadPlaybooks() }
        .themeBackground()
        .navigationTitle("Playbooks")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(Color.theme.mutedForeground)
                }
                .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $vm.showCreateSheet) {
            CreatePlaybookSheet(vm: vm)
        }
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView(
                vm: SettingsViewModel(
                    tokenManager: tokenManager,
                    authService: authService,
                    syncEngine: syncEngine,
                    onSignOut: onSignOut
                )
            )
        }
    }

    // MARK: - Playbook List

    private var playbookList: some View {
        LazyVStack(spacing: 12) {
            ForEach(vm.filteredPlaybooks, id: \.id) { playbook in
                PlaybookCardRow(
                    playbook: playbook,
                    taskService: taskService,
                    sectionService: sectionService,
                    weeklyPlanService: weeklyPlanService,
                    syncEngine: syncEngine,
                    onArchive: { vm.archivePlaybook(id: playbook.id) }
                )
                .accessibilityIdentifier("playbook_row_\(playbook.id)")
            }

            NewPlaybookButton(onTap: { vm.showCreateSheet = true })
                .accessibilityIdentifier("new_playbook_button")
                .padding(.top, 4)
        }
        .drawingGroup()
    }

}

// MARK: - Playbook Card Row

/// A single playbook card with phase badge, task count, and interaction gestures.
private struct PlaybookCardRow: View {

    let playbook: PlaybookModel
    let taskService: any TaskServiceProtocol
    let sectionService: any SectionServiceProtocol
    let weeklyPlanService: any WeeklyPlanServiceProtocol
    let syncEngine: SyncEngine?
    let onArchive: () -> Void

    private var nowTaskCount: Int {
        playbook.tasks.filter { $0.lane == .now && $0.status == .open }.count
    }

    var body: some View {
        NavigationLink {
            PlaybookHomeView(vm: PlaybookHomeViewModel(playbook: playbook, taskService: taskService, sectionService: sectionService, weeklyPlanService: weeklyPlanService, syncEngine: syncEngine))
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(playbook.title)
                        .font(.theme.body)
                        .foregroundStyle(Color.theme.foreground)
                        .lineLimit(1)

                    PhaseBadge(phase: playbook.phase)

                    if nowTaskCount > 0 {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.theme.phaseProof)
                                .frame(width: 6, height: 6)

                            Text("\(nowTaskCount) task\(nowTaskCount == 1 ? "" : "s") in Now")
                                .font(.theme.caption)
                                .foregroundStyle(Color.theme.mutedForeground)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.theme.mutedForeground)
            }
            .padding(16)
            .cardStyle()
        }
        .buttonStyle(.pressable)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                onArchive()
            } label: {
                Label("Archive", systemImage: "archivebox")
            }
            .tint(.orange)
        }
        .contextMenu {
            Button {
                onArchive()
            } label: {
                Label("Archive", systemImage: "archivebox")
            }

            Button(role: .destructive) {
                // Delete placeholder — future issue
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(playbook.title), \(playbook.phase.rawValue) phase"
            + (nowTaskCount > 0 ? ", \(nowTaskCount) task\(nowTaskCount == 1 ? "" : "s") in Now" : "")
        )
        .accessibilityHint("Tap to open playbook")
    }
}

// MARK: - New Playbook Button

/// A dashed-border button at the bottom of the list to create a new playbook.
private struct NewPlaybookButton: View {

    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))

                Text("New Playbook")
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
        .accessibilityLabel("Create new playbook")
    }
}

// MARK: - Create Playbook Sheet

/// Half-sheet for creating a new playbook with title and optional description.
private struct CreatePlaybookSheet: View {

    @Bindable var vm: PlaybookListViewModel
    @Environment(\.dismiss) private var dismiss

    private var isTitleEmpty: Bool {
        vm.newPlaybookTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TITLE")
                            .font(.theme.overline)
                            .foregroundStyle(Color.theme.mutedForeground)
                            .tracking(1.0)

                        TextField("My new playbook", text: $vm.newPlaybookTitle)
                            .font(.theme.bodyRegular)
                            .foregroundStyle(Color.theme.foreground)
                            .textInputAutocapitalization(.sentences)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.theme.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: .theme.radiusMd))
                            .overlay(
                                RoundedRectangle(cornerRadius: .theme.radiusMd)
                                    .stroke(Color.theme.input, lineWidth: 1)
                            )
                            .accessibilityLabel("Playbook title")
                            .accessibilityIdentifier("create_playbook_title")
                    }

                    // Description field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DESCRIPTION")
                            .font(.theme.overline)
                            .foregroundStyle(Color.theme.mutedForeground)
                            .tracking(1.0)

                        Text("Optional")
                            .font(.theme.caption)
                            .foregroundStyle(Color.theme.mutedForeground)

                        TextField("What's this playbook about?", text: $vm.newPlaybookDescription, axis: .vertical)
                            .font(.theme.bodyRegular)
                            .foregroundStyle(Color.theme.foreground)
                            .lineLimit(3...6)
                            .textInputAutocapitalization(.sentences)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.theme.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: .theme.radiusMd))
                            .overlay(
                                RoundedRectangle(cornerRadius: .theme.radiusMd)
                                    .stroke(Color.theme.input, lineWidth: 1)
                            )
                            .accessibilityLabel("Playbook description, optional")
                    }

                    // Create button
                    Button {
                        vm.createPlaybook()
                    } label: {
                        Text("Create")
                            .font(.theme.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.theme.primaryForeground)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 50)
                            .background(isTitleEmpty ? Color.theme.muted : Color.theme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: .theme.radiusMd))
                            .shadow(
                                color: isTitleEmpty ? .clear : Color.theme.primary.opacity(0.4),
                                radius: 12, y: 4
                            )
                    }
                    .buttonStyle(.pressable)
                    .disabled(isTitleEmpty)
                    .accessibilityLabel("Create playbook")
                    .accessibilityHint(isTitleEmpty ? "Enter a title first" : "Creates a new playbook")
                    .accessibilityIdentifier("create_playbook_submit")
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("New Playbook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        vm.newPlaybookTitle = ""
                        vm.newPlaybookDescription = ""
                        vm.showCreateSheet = false
                    }
                    .foregroundStyle(Color.theme.mutedForeground)
                }
            }
            .themeBackground()
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.theme.background)
    }
}

// MARK: - Preview

private let previewTokenManager = TokenManager(baseURL: URL(string: "https://api.test.ideapilot.app")!)

#Preview("Populated") {
    NavigationStack {
        PlaybookListView(
            vm: {
                let vm = PlaybookListViewModel(playbookService: PlaybookListPreviewPlaybookService())
                vm.playbooks = [
                    PlaybookModel(id: "1", title: "Side Hustle App", phase: .proof),
                    PlaybookModel(id: "2", title: "Freelance Business", phase: .structure),
                    PlaybookModel(id: "3", title: "Content Platform", phase: .repeatability),
                    PlaybookModel(id: "4", title: "SaaS Product", phase: .growth),
                ]
                return vm
            }(),
            taskService: PlaybookListPreviewTaskService(),
            sectionService: PlaybookListPreviewSectionService(),
            weeklyPlanService: PlaybookListPreviewWeeklyPlanService(),
            tokenManager: previewTokenManager,
            authService: PlaybookListPreviewAuthService(),
            syncEngine: nil,
            onSignOut: {}
        )
    }
}

#Preview("Empty") {
    NavigationStack {
        PlaybookListView(
            vm: PlaybookListViewModel(playbookService: PlaybookListPreviewPlaybookService()),
            taskService: PlaybookListPreviewTaskService(),
            sectionService: PlaybookListPreviewSectionService(),
            weeklyPlanService: PlaybookListPreviewWeeklyPlanService(),
            tokenManager: previewTokenManager,
            authService: PlaybookListPreviewAuthService(),
            syncEngine: nil,
            onSignOut: {}
        )
    }
}

#Preview("Error") {
    NavigationStack {
        PlaybookListView(
            vm: {
                let vm = PlaybookListViewModel(playbookService: PlaybookListPreviewPlaybookService())
                vm.error = "Network error. Please check your connection."
                return vm
            }(),
            taskService: PlaybookListPreviewTaskService(),
            sectionService: PlaybookListPreviewSectionService(),
            weeklyPlanService: PlaybookListPreviewWeeklyPlanService(),
            tokenManager: previewTokenManager,
            authService: PlaybookListPreviewAuthService(),
            syncEngine: nil,
            onSignOut: {}
        )
    }
}

/// A no-op playbook service for SwiftUI previews.
private struct PlaybookListPreviewPlaybookService: PlaybookServiceProtocol {
    func fetchPlaybooks(updatedSince: Date?) async throws -> [PlaybookModel] { [] }
    func createPlaybook(title: String, description: String?) async throws -> PlaybookModel {
        PlaybookModel(id: UUID().uuidString, title: title)
    }
    func archivePlaybook(id: String) async throws {}
}

/// A no-op section service for SwiftUI previews.
private struct PlaybookListPreviewSectionService: SectionServiceProtocol {
    func fetchSections(playbookId: String, updatedSince: Date?) async throws -> [SectionModel] { [] }
    func updateSection(playbookId: String, sectionType: SectionType, content: String) async throws -> SectionModel {
        SectionModel(playbookId: playbookId, sectionType: sectionType, content: content)
    }
}

/// A no-op weekly plan service for SwiftUI previews.
private struct PlaybookListPreviewWeeklyPlanService: WeeklyPlanServiceProtocol {
    func getWeeklyStatus(playbookId: String) async throws -> WeeklyCycleModel {
        WeeklyCycleModel(playbookId: playbookId, weekStartDate: .now)
    }
    func createWeeklyPlan(playbookId: String, taskIds: [String]) async throws -> WeeklyCycleModel {
        WeeklyCycleModel(playbookId: playbookId, weekStartDate: .now, totalCount: taskIds.count)
    }
    func fetchWeeklyCycles(playbookId: String) async throws -> [WeeklyCycleModel] { [] }
}

/// A no-op auth service for SwiftUI previews.
private struct PlaybookListPreviewAuthService: AuthServiceProtocol {
    func login(email: String, password: String) async throws -> UserSession {
        UserSession(userId: "1", email: email, accessToken: "t", refreshToken: "r")
    }
    func register(email: String, password: String) async throws -> UserSession {
        UserSession(userId: "1", email: email, accessToken: "t", refreshToken: "r")
    }
    func auth0Login(idToken: String) async throws -> UserSession {
        UserSession(userId: "1", email: "test@test.com", accessToken: "t", refreshToken: "r")
    }
    func logout() async throws {}
}

/// A no-op task service for SwiftUI previews.
private struct PlaybookListPreviewTaskService: TaskServiceProtocol {
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
