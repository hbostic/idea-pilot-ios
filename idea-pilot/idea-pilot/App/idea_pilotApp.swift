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

    init() {
        let container = try! ModelContainer(for: PlaybookModel.self)
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

        let playbooks = PlaybookService(apiClient: client, modelContainer: container)
        let tasks = TaskService(apiClient: client, modelContainer: container)
        let sections = SectionService(apiClient: client, modelContainer: container)

        self.modelContainer = container
        self.tokenManager = tm
        self.apiClient = client
        self.authService = auth
        self.playbookService = playbooks
        self.taskService = tasks
        self.sectionService = sections
    }

    var body: some Scene {
        WindowGroup {
            RootView(tokenManager: tokenManager, authService: authService, playbookService: playbookService, taskService: taskService, sectionService: sectionService)
        }
        .modelContainer(modelContainer)
    }
}
