//
//  MainTabView.swift
//  idea-pilot
//
//  Custom 3-tab bottom bar: Now, Create (+), Playbooks.
//  Uses a glass-effect custom tab bar instead of the system TabView.
//

import SwiftUI

// MARK: - Tab Model

/// The selectable tabs in the main tab bar.
///
/// Capture is not included because it opens a sheet overlay
/// rather than switching the active tab.
enum AppTab: Int, CaseIterable {
    case now
    case playbooks

    var label: String {
        switch self {
        case .now: "Now"
        case .playbooks: "Playbooks"
        }
    }

    var activeIcon: String {
        switch self {
        case .now: "play.fill"
        case .playbooks: "square.stack.fill"
        }
    }

    var inactiveIcon: String {
        switch self {
        case .now: "play"
        case .playbooks: "square.stack"
        }
    }
}

// MARK: - MainTabView

/// The main tab bar shown when the user is authenticated.
///
/// Features a custom glass-effect tab bar with three items:
/// - **Now** — Playbook home (left)
/// - **Create (+)** — Opens the Quick Add sheet (center, larger purple icon)
/// - **Playbooks** — Playbook list (right)
///
/// Both Now and Playbooks maintain their own `NavigationStack` so
/// navigation state is preserved when switching tabs.
struct MainTabView: View {

    /// Called when the user taps sign out. Owned by RootView.
    var onSignOut: () -> Void

    let taskService: any TaskServiceProtocol
    let playbookService: any PlaybookServiceProtocol
    let sectionService: any SectionServiceProtocol
    let weeklyPlanService: any WeeklyPlanServiceProtocol
    let tokenManager: TokenManager
    let authService: any AuthServiceProtocol
    let syncEngine: SyncEngine?

    @State private var selectedTab: AppTab = .now
    @State private var playbookListVM: PlaybookListViewModel
    @State private var showQuickAddSheet = false

    init(playbookService: any PlaybookServiceProtocol, taskService: any TaskServiceProtocol, sectionService: any SectionServiceProtocol, weeklyPlanService: any WeeklyPlanServiceProtocol, tokenManager: TokenManager, authService: any AuthServiceProtocol, syncEngine: SyncEngine?, onSignOut: @escaping () -> Void) {
        self.onSignOut = onSignOut
        self.taskService = taskService
        self.playbookService = playbookService
        self.sectionService = sectionService
        self.weeklyPlanService = weeklyPlanService
        self.tokenManager = tokenManager
        self.authService = authService
        self.syncEngine = syncEngine
        self._playbookListVM = State(initialValue: PlaybookListViewModel(playbookService: playbookService))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content — both always present to preserve NavigationStack state.
            tabContent

            // Custom glass tab bar overlay.
            CustomTabBar(
                selectedTab: $selectedTab,
                onCaptureTap: { showQuickAddSheet = true }
            )
        }
        .themeBackground()
        .sheet(isPresented: $showQuickAddSheet) {
            QuickAddSheet(
                vm: QuickAddViewModel(
                    taskService: taskService,
                    playbookService: playbookService
                )
            )
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        ZStack {
            NavigationStack {
                NowPlaceholderView(onSignOut: onSignOut)
            }
            .opacity(selectedTab == .now ? 1 : 0)

            NavigationStack {
                PlaybookListView(vm: playbookListVM, taskService: taskService, sectionService: sectionService, weeklyPlanService: weeklyPlanService, tokenManager: tokenManager, authService: authService, syncEngine: syncEngine, onSignOut: onSignOut)
            }
            .opacity(selectedTab == .playbooks ? 1 : 0)
        }
    }
}

// MARK: - Custom Tab Bar

/// A glass-effect bottom tab bar with Now, Capture, and Playbooks buttons.
///
/// The center capture button has a distinct raised purple circle style.
/// Active tabs show filled icons with labels; inactive tabs show outline icons only.
private struct CustomTabBar: View {

    @Binding var selectedTab: AppTab
    var onCaptureTap: () -> Void
    @State private var tappedTab: AppTab?

    var body: some View {
        HStack {
            tabButton(.now)

            Spacer()

            captureButton

            Spacer()

            tabButton(.playbooks)
        }
        .padding(.horizontal, 32)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .glassStyle()
    }

    // MARK: - Regular Tab Button

    private func tabButton(_ tab: AppTab) -> some View {
        Button {
            tappedTab = tab
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: selectedTab == tab ? tab.activeIcon : tab.inactiveIcon)
                    .font(.system(size: 22))

                if selectedTab == tab {
                    Text(tab.label)
                        .font(.theme.caption)
                }
            }
            .foregroundStyle(selectedTab == tab ? Color.theme.primary : Color.theme.mutedForeground)
            .scaleEffect(tappedTab == tab ? 0.85 : 1.0)
            .frame(minWidth: 56, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onChange(of: tappedTab) { _, newValue in
            if newValue == tab {
                let animation: Animation? = UIAccessibility.isReduceMotionEnabled
                    ? nil
                    : .spring(response: 0.3, dampingFraction: 0.5)
                withAnimation(animation) {
                    tappedTab = nil
                }
            }
        }
        .accessibilityLabel("\(tab.label) tab")
        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
        .accessibilityIdentifier("tab_\(tab.label.lowercased())")
    }

    // MARK: - Capture Button (Center)

    private var captureButton: some View {
        Button {
            onCaptureTap()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Color.theme.primary)
                .clipShape(Circle())
                .shadow(color: Color.theme.primary.opacity(0.4), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Create new task")
        .accessibilityIdentifier("tab_capture")
        .offset(y: -8)
    }
}

// MARK: - Placeholder Tab Views

/// Placeholder for the Now tab content.
private struct NowPlaceholderView: View {

    var onSignOut: () -> Void

    var body: some View {
        ZStack {
            Color.theme.background
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Now")
                    .font(.theme.largeTitle)
                    .foregroundStyle(Color.theme.foreground)

                Text("Coming soon")
                    .font(.theme.subheadline)
                    .foregroundStyle(Color.theme.mutedForeground)

                Button {
                    onSignOut()
                } label: {
                    Text("Sign Out")
                        .font(.theme.body)
                        .foregroundStyle(Color.theme.destructive)
                }
                .accessibilityLabel("Sign out")
            }
        }
        .safeAreaPadding(.bottom, 72)
    }
}

// MARK: - Preview

#Preview {
    MainTabView(
        playbookService: MainTabPreviewPlaybookService(),
        taskService: MainTabPreviewTaskService(),
        sectionService: MainTabPreviewSectionService(),
        weeklyPlanService: MainTabPreviewWeeklyPlanService(),
        tokenManager: TokenManager(baseURL: URL(string: "https://api.test.ideapilot.app")!),
        authService: MainTabPreviewAuthService(),
        syncEngine: nil,
        onSignOut: {}
    )
}

/// A no-op auth service for MainTabView previews.
private struct MainTabPreviewAuthService: AuthServiceProtocol {
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

/// A no-op playbook service for MainTabView previews.
private struct MainTabPreviewPlaybookService: PlaybookServiceProtocol {
    func fetchPlaybooks(updatedSince: Date?) async throws -> [PlaybookModel] { [] }
    func createPlaybook(title: String, description: String?) async throws -> PlaybookModel {
        PlaybookModel(id: UUID().uuidString, title: title)
    }
    func archivePlaybook(id: String) async throws {}
}

/// A no-op section service for MainTabView previews.
private struct MainTabPreviewSectionService: SectionServiceProtocol {
    func fetchSections(playbookId: String, updatedSince: Date?) async throws -> [SectionModel] { [] }
    func updateSection(playbookId: String, sectionType: SectionType, content: String) async throws -> SectionModel {
        SectionModel(playbookId: playbookId, sectionType: sectionType, content: content)
    }
}

/// A no-op weekly plan service for MainTabView previews.
private struct MainTabPreviewWeeklyPlanService: WeeklyPlanServiceProtocol {
    func getWeeklyStatus(playbookId: String) async throws -> WeeklyCycleModel {
        WeeklyCycleModel(playbookId: playbookId, weekStartDate: .now)
    }
    func createWeeklyPlan(playbookId: String, taskIds: [String]) async throws -> WeeklyCycleModel {
        WeeklyCycleModel(playbookId: playbookId, weekStartDate: .now, totalCount: taskIds.count)
    }
    func fetchWeeklyCycles(playbookId: String) async throws -> [WeeklyCycleModel] { [] }
}

/// A no-op task service for MainTabView previews.
private struct MainTabPreviewTaskService: TaskServiceProtocol {
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
