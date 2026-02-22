//
//  MainTabView.swift
//  idea-pilot
//
//  Placeholder tab bar for the authenticated state.
//  Real tab content will be added in future milestones.
//

import SwiftUI

/// The main tab bar shown when the user is authenticated.
///
/// Currently contains placeholder tabs. Future milestones will replace these
/// with real content (Now lane, Playbook list, etc.).
struct MainTabView: View {

    /// Called when the user taps sign out. Owned by RootView.
    var onSignOut: () -> Void

    var body: some View {
        TabView {
            Tab("Now", systemImage: "bolt.fill") {
                placeholderTab("Now")
            }

            Tab("Playbooks", systemImage: "book.fill") {
                placeholderTab("Playbooks")
            }
        }
        .tint(Color.theme.primary)
    }

    private func placeholderTab(_ title: String) -> some View {
        ZStack {
            Color.theme.background
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text(title)
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
            }
        }
    }
}

#Preview {
    MainTabView(onSignOut: {})
}
