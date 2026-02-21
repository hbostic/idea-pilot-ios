//
//  idea_pilotApp.swift
//  idea-pilot
//
//  Created by Harold Bostic on 2/21/26.
//

import SwiftUI

/// The main entry point for the Idea Pilot iOS app.
///
/// This struct bootstraps the app window and sets the root view.
/// Future milestones will add:
/// - `ModelContainer` for SwiftData persistence (Issue #5)
/// - Environment objects for auth state and sync engine
/// - Deep link handling
@main
struct idea_pilotApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
