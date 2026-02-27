//
//  idea_pilotApp.swift
//  idea-pilot
//
//  Main entry point for the Idea Pilot iOS app.
//  Bootstraps the dependency graph and sets the root view.
//

import SwiftData
import SwiftUI

/// The main entry point for the Idea Pilot iOS app.
///
/// Creates the full dependency graph at startup:
/// `ModelContainer` → `TokenManager` → `APIClient` → `AuthService`
///
/// These are passed to `RootView` which gates on authentication state.
@main
struct idea_pilotApp: App {

    let modelContainer: ModelContainer
    let tokenManager: TokenManager
    let apiClient: APIClient
    let authService: AuthService
    let playbookService: PlaybookService
    let taskService: TaskService
    let sectionService: SectionService
    let weeklyPlanService: WeeklyPlanService
    let syncEngine: SyncEngine

    init() {
        let container = try! ModelContainer(for: PlaybookModel.self, MutationEntry.self)
        let tm = TokenManager(
            keychain: KeychainService(),
            baseURL: AppConfiguration.apiBaseURL
        )
        let client = APIClient(
            baseURL: AppConfiguration.apiBaseURL,
            tokenProvider: tm
        )
        let auth = AuthService(
            apiClient: client,
            tokenManager: tm,
            modelContainer: container
        )

        let sync = SyncEngine(apiClient: client, modelContainer: container)

        let playbooks = PlaybookService(apiClient: client, modelContainer: container, syncEngine: sync)
        let tasks = TaskService(apiClient: client, modelContainer: container, syncEngine: sync)
        let sections = SectionService(apiClient: client, modelContainer: container, syncEngine: sync)
        let weeklyPlan = WeeklyPlanService(apiClient: client, modelContainer: container, syncEngine: sync)

        self.modelContainer = container
        self.tokenManager = tm
        self.apiClient = client
        self.authService = auth
        self.syncEngine = sync
        self.playbookService = playbooks
        self.taskService = tasks
        self.sectionService = sections
        self.weeklyPlanService = weeklyPlan

        sync.start()
    }

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(tokenManager: tokenManager, authService: authService, playbookService: playbookService, taskService: taskService, sectionService: sectionService, weeklyPlanService: weeklyPlanService, syncEngine: syncEngine)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        syncEngine.onAppForeground()
                    }
                }
        }
        .modelContainer(modelContainer)
    }
}
