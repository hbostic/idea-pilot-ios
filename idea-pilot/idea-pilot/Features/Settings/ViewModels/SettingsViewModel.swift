//
//  SettingsViewModel.swift
//  idea-pilot
//
//  ViewModel for the Settings screen.
//  Manages account info, sync status display, and sign-out flow.
//

import Foundation

/// ViewModel driving the Settings screen.
///
/// Loads the user's email from `TokenManager`, exposes sync status
/// from `SyncEngine`, and manages the sign-out flow with a confirmation
/// dialog when unsynced mutations are pending.
@Observable
final class SettingsViewModel {

    // MARK: - State

    /// The authenticated user's email address.
    var email: String?

    /// Whether a manual sync is in progress.
    var isSyncing = false

    /// Triggers the sign-out confirmation dialog.
    var showSignOutConfirmation = false

    // MARK: - Dependencies

    private let tokenManager: TokenManager
    private let authService: any AuthServiceProtocol
    private let syncEngine: SyncEngine?
    private let onSignOut: () -> Void

    // MARK: - Init

    /// Creates a SettingsViewModel.
    ///
    /// - Parameters:
    ///   - tokenManager: Provides user email and auth state.
    ///   - authService: Handles logout API call.
    ///   - syncEngine: Provides sync status and manual sync trigger.
    ///   - onSignOut: Callback fired after sign-out completes.
    init(
        tokenManager: TokenManager,
        authService: any AuthServiceProtocol,
        syncEngine: SyncEngine?,
        onSignOut: @escaping () -> Void
    ) {
        self.tokenManager = tokenManager
        self.authService = authService
        self.syncEngine = syncEngine
        self.onSignOut = onSignOut
    }

    // MARK: - Computed

    /// The current sync status value from the engine.
    var syncStatusValue: SyncStatusValue {
        syncEngine?.status.value ?? .synced
    }

    /// Number of mutations waiting to be synced.
    var pendingCount: Int {
        syncEngine?.mutationQueue.pendingCount ?? 0
    }

    /// Whether unsynced mutations exist in the queue.
    var hasPendingMutations: Bool {
        pendingCount > 0
    }

    /// Whether the device is currently connected to the network.
    var isConnected: Bool {
        syncEngine?.networkMonitor.isConnected ?? true
    }

    /// Formatted last sync timestamp, or `nil` if never synced.
    var lastSyncText: String? {
        guard let date = syncEngine?.lastSyncDate else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    /// The app version string for display.
    var appVersion: String {
        AppConfiguration.versionDisplay
    }

    // MARK: - Actions

    /// Loads the user's email from the TokenManager actor.
    func loadEmail() async {
        email = await tokenManager.email
    }

    /// Triggers a manual sync. Awaitable for UI spinner binding.
    func syncNow() async {
        guard !isSyncing else { return }
        isSyncing = true
        await syncEngine?.onPullToRefresh()
        isSyncing = false
    }

    /// Initiates sign-out. Shows confirmation if unsynced mutations exist.
    func confirmSignOut() {
        if hasPendingMutations {
            showSignOutConfirmation = true
        } else {
            performSignOut()
        }
    }

    /// Executes the sign-out: logs out via API, then fires the callback.
    func performSignOut() {
        Task {
            try? await authService.logout()
        }
        onSignOut()
    }
}
