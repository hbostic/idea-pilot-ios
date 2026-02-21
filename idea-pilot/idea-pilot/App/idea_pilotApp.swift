//
//  idea_pilotApp.swift
//  idea-pilot
//
//  Created by Harold Bostic on 2/21/26.
//

import SwiftData
import SwiftUI

/// The main entry point for the Idea Pilot iOS app.
///
/// Bootstraps the app window, registers the SwiftData `ModelContainer`,
/// and sets the root view. SwiftData discovers all related models
/// (TaskModel, SectionModel, WeeklyCycleModel) via PlaybookModel's relationships.
///
/// Future milestones will add:
/// - Environment objects for auth state and sync engine
/// - Deep link handling
@main
struct idea_pilotApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: PlaybookModel.self)
    }
}
