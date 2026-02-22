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

        self.modelContainer = container
        self.tokenManager = tm
        self.apiClient = client
        self.authService = auth
    }

    var body: some Scene {
        WindowGroup {
            RootView(tokenManager: tokenManager, authService: authService)
        }
        .modelContainer(modelContainer)
    }
}
