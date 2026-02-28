//
//  SettingsView.swift
//  idea-pilot
//
//  Full-screen settings modal with account, sync status, and sign-out.
//  Accessible from the gear icon in PlaybookListView.
//

import SwiftUI

/// The Settings screen presented as a full-screen modal.
///
/// Sections:
/// 1. **Account** — user email
/// 2. **Sync** — status indicator, last sync time, pending count, Sync Now button
/// 3. **About** — app version, links placeholder
/// 4. **Sign Out** — destructive button with confirmation when mutations pending
struct SettingsView: View {

    @Bindable var vm: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    accountSection
                    syncSection
                    aboutSection
                    signOutButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .themeBackground()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.theme.primary)
                }
            }
            .task { await vm.loadEmail() }
            .confirmationDialog(
                "Sign Out?",
                isPresented: $vm.showSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    vm.performSignOut()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You have unsynced changes that will be lost.")
            }
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("ACCOUNT")

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.theme.mutedForeground)

                    Text(vm.email ?? "Loading…")
                        .font(.theme.body)
                        .foregroundStyle(Color.theme.foreground)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .cardStyle()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Account, \(vm.email ?? "loading")")
    }

    // MARK: - Sync Section

    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("SYNC")

            VStack(spacing: 0) {
                // Status row
                settingsRow {
                    HStack(spacing: 8) {
                        Text("Status")
                            .font(.theme.body)
                            .foregroundStyle(Color.theme.foreground)

                        Spacer()

                        syncStatusIndicator
                    }
                }

                Divider()
                    .background(Color.theme.border)

                // Last sync row
                settingsRow {
                    HStack {
                        Text("Last Sync")
                            .font(.theme.body)
                            .foregroundStyle(Color.theme.foreground)

                        Spacer()

                        Text(vm.lastSyncText ?? "Never")
                            .font(.theme.subheadline)
                            .foregroundStyle(Color.theme.mutedForeground)
                    }
                }

                if vm.pendingCount > 0 {
                    Divider()
                        .background(Color.theme.border)

                    // Pending mutations row
                    settingsRow {
                        HStack {
                            Text("Pending Changes")
                                .font(.theme.body)
                                .foregroundStyle(Color.theme.foreground)

                            Spacer()

                            Text("\(vm.pendingCount)")
                                .font(.theme.subheadline)
                                .foregroundStyle(Color.yellow)
                        }
                    }
                }

                Divider()
                    .background(Color.theme.border)

                // Sync Now button row
                settingsRow {
                    Button {
                        Task { await vm.syncNow() }
                    } label: {
                        HStack {
                            Text("Sync Now")
                                .font(.theme.body)
                                .foregroundStyle(
                                    vm.isConnected && !vm.isSyncing
                                        ? Color.theme.primary
                                        : Color.theme.mutedForeground
                                )

                            Spacer()

                            if vm.isSyncing {
                                ProgressView()
                                    .tint(Color.theme.primary)
                            }
                        }
                    }
                    .disabled(!vm.isConnected || vm.isSyncing)
                    .accessibilityLabel("Sync now")
                    .accessibilityHint(
                        vm.isConnected
                            ? "Triggers an immediate sync"
                            : "Unavailable while offline"
                    )
                }
            }
            .cardStyle()
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("ABOUT")

            VStack(spacing: 0) {
                settingsRow {
                    HStack {
                        Text("Version")
                            .font(.theme.body)
                            .foregroundStyle(Color.theme.foreground)

                        Spacer()

                        Text(vm.appVersion)
                            .font(.theme.subheadline)
                            .foregroundStyle(Color.theme.mutedForeground)
                    }
                }

                Divider()
                    .background(Color.theme.border)

                settingsRow {
                    HStack {
                        Text("Links")
                            .font(.theme.body)
                            .foregroundStyle(Color.theme.foreground)

                        Spacer()

                        Text("Coming soon")
                            .font(.theme.subheadline)
                            .foregroundStyle(Color.theme.mutedForeground)
                    }
                }
            }
            .cardStyle()
        }
    }

    // MARK: - Sign Out Button

    private var signOutButton: some View {
        Button {
            vm.confirmSignOut()
        } label: {
            Text("Sign Out")
                .font(.theme.body)
                .fontWeight(.semibold)
                .foregroundStyle(Color.theme.destructive)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.theme.destructive.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: .theme.radiusMd))
                .overlay(
                    RoundedRectangle(cornerRadius: .theme.radiusMd)
                        .stroke(Color.theme.destructive.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Sign out")
        .accessibilityHint(
            vm.hasPendingMutations
                ? "You have unsynced changes"
                : "Signs you out of your account"
        )
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.theme.overline)
            .foregroundStyle(Color.theme.mutedForeground)
            .tracking(1.0)
    }

    private func settingsRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
    }

    @ViewBuilder
    private var syncStatusIndicator: some View {
        switch vm.syncStatusValue {
        case .synced:
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("Synced")
                    .font(.theme.subheadline)
                    .foregroundStyle(Color.theme.mutedForeground)
            }
            .accessibilityLabel("Synced")

        case .syncing:
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(Color.theme.primary)
                Text("Syncing…")
                    .font(.theme.subheadline)
                    .foregroundStyle(Color.theme.primary)
            }
            .accessibilityLabel("Syncing")

        case .pending(let count):
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 8, height: 8)
                Text("\(count) pending")
                    .font(.theme.subheadline)
                    .foregroundStyle(Color.theme.mutedForeground)
            }
            .accessibilityLabel("\(count) changes pending")

        case .error(let message):
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.theme.destructive)
                    .frame(width: 8, height: 8)
                Text("Error")
                    .font(.theme.subheadline)
                    .foregroundStyle(Color.theme.destructive)
            }
            .accessibilityLabel("Sync error: \(message)")

        case .offline:
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.gray)
                    .frame(width: 8, height: 8)
                Text("Offline")
                    .font(.theme.subheadline)
                    .foregroundStyle(Color.theme.mutedForeground)
            }
            .accessibilityLabel("Offline")
        }
    }
}
