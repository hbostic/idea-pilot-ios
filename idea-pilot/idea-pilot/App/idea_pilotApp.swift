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
    let authService: any AuthServiceProtocol
    let playbookService: any PlaybookServiceProtocol
    let taskService: any TaskServiceProtocol
    let sectionService: any SectionServiceProtocol
    let weeklyPlanService: any WeeklyPlanServiceProtocol
    let syncEngine: SyncEngine?

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("UI_TEST_MODE") {
            let container = try! ModelContainer(
                for: PlaybookModel.self, MutationEntry.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            let isSignedOut = ProcessInfo.processInfo.arguments.contains("UI_TEST_SIGNED_OUT")
            let mockKeychain = UITestMockKeychainService()
            if !isSignedOut {
                try! mockKeychain.save("test-access", forKey: "com.lifeautomation.idea-pilot.accessToken")
                try! mockKeychain.save("test-refresh", forKey: "com.lifeautomation.idea-pilot.refreshToken")
                try! mockKeychain.save("uitest-1", forKey: "com.lifeautomation.idea-pilot.userId")
                try! mockKeychain.save("test@example.com", forKey: "com.lifeautomation.idea-pilot.email")
            }
            let tm = TokenManager(keychain: mockKeychain, baseURL: URL(string: "https://test.api")!)
            let client = APIClient(baseURL: URL(string: "https://test.api")!, tokenProvider: tm)

            self.modelContainer = container
            self.tokenManager = tm
            self.apiClient = client
            self.authService = UITestAuthService(tokenManager: tm)
            self.playbookService = UITestPlaybookService()
            self.taskService = UITestTaskService()
            self.sectionService = UITestSectionService()
            self.weeklyPlanService = UITestWeeklyPlanService()
            self.syncEngine = nil
            return
        }
        #endif

        guard let container = try? ModelContainer(for: PlaybookModel.self, MutationEntry.self) else {
            fatalError("Failed to initialize SwiftData ModelContainer. The app cannot function without local storage.")
        }
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
                        syncEngine?.onAppForeground()
                    }
                }
        }
        .modelContainer(modelContainer)
    }
}
