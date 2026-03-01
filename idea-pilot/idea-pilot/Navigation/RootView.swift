//
//  RootView.swift
//  idea-pilot
//
//  Root navigation gate that routes based on authentication state.
//  Unauthenticated → AuthView, Authenticated → MainTabView.
//

import SwiftUI

/// The root view that gates on authentication state.
///
/// On launch, checks `TokenManager.isAuthenticated`:
/// - If tokens exist → show `MainTabView` (attempt background refresh)
/// - If no tokens → show `AuthView`
///
/// Transitions are animated with a crossfade for a polished experience.
struct RootView: View {

    let tokenManager: TokenManager
    let authService: any AuthServiceProtocol
    let playbookService: any PlaybookServiceProtocol
    let taskService: any TaskServiceProtocol
    let sectionService: any SectionServiceProtocol
    let weeklyPlanService: any WeeklyPlanServiceProtocol
    let syncEngine: SyncEngine?

    @State private var isAuthenticated = false
    @State private var isCheckingAuth = true
    @State private var authViewModel: AuthViewModel?

    var body: some View {
        Group {
            if isCheckingAuth {
                splashView
            } else if isAuthenticated {
                MainTabView(playbookService: playbookService, taskService: taskService, sectionService: sectionService, weeklyPlanService: weeklyPlanService, tokenManager: tokenManager, authService: authService, syncEngine: syncEngine, onSignOut: signOut)
            } else if let vm = authViewModel {
                AuthView(vm: vm)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: isCheckingAuth)
        .task { await checkAuthState() }
        .onChange(of: authViewModel?.isAuthenticated) { _, newValue in
            if newValue == true {
                isAuthenticated = true
            }
        }
    }

    // MARK: - Splash (shown briefly during auth check)

    private var splashView: some View {
        ZStack {
            Color.theme.background
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "play.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(Color.theme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: .theme.radiusLg))
                    .shadow(color: Color.theme.primary.opacity(0.5), radius: 20, y: 4)
                    .accessibilityHidden(true)

                Text("Idea Pilot")
                    .font(.theme.largeTitle)
                    .foregroundStyle(Color.theme.foreground)
            }
        }
    }

    // MARK: - Auth State

    private func checkAuthState() async {
        let authenticated = await tokenManager.isAuthenticated
        if authenticated {
            isAuthenticated = true
            isCheckingAuth = false
            // Attempt background token refresh for returning users.
            Task {
                try? await tokenManager.refresh()
            }
        } else {
            authViewModel = AuthViewModel(authService: authService)
            isCheckingAuth = false
        }
    }

    private func signOut() {
        syncEngine?.stop()
        guard let vm = authViewModel else {
            // Create a fresh ViewModel for the auth screen.
            let newVM = AuthViewModel(authService: authService)
            authViewModel = newVM
            Task {
                try? await authService.logout()
            }
            isAuthenticated = false
            return
        }
        vm.signOut()
        isAuthenticated = false
    }
}
