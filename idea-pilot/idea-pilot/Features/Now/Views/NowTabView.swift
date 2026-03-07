//
//  NowTabView.swift
//  idea-pilot
//
//  The Now tab content — shows PlaybookHomeView for the last-viewed playbook,
//  or an empty state prompting the user to create their first playbook.
//

import SwiftUI

/// The Now tab's root view.
///
/// Resolves the last-viewed playbook and renders `PlaybookHomeView` for it.
/// If no playbooks exist, shows an empty state with a "Create Playbook" CTA.
struct NowTabView: View {

    @Bindable var vm: NowTabViewModel
    let taskService: any TaskServiceProtocol
    let sectionService: any SectionServiceProtocol
    let weeklyPlanService: any WeeklyPlanServiceProtocol
    let syncEngine: SyncEngine?
    let onSignOut: () -> Void

    var body: some View {
        Group {
            if vm.isLoading && vm.playbook == nil {
                loadingView
            } else if let playbook = vm.playbook {
                PlaybookHomeView(vm: PlaybookHomeViewModel(
                    playbook: playbook,
                    taskService: taskService,
                    sectionService: sectionService,
                    weeklyPlanService: weeklyPlanService,
                    syncEngine: syncEngine
                ))
            } else {
                emptyState
            }
        }
        .onAppear { vm.loadPlaybook() }
        .sheet(isPresented: $vm.showCreateSheet) {
            NowCreatePlaybookSheet(vm: vm)
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        ZStack {
            Color.theme.background
                .ignoresSafeArea()

            ProgressView()
                .tint(Color.theme.mutedForeground)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let error = vm.error {
                    ErrorBannerView(message: error)
                }

                EmptyStateView(
                    icon: "play.circle",
                    title: "No playbooks yet",
                    message: "Create your first playbook to start executing",
                    actionTitle: "Create Playbook",
                    onAction: { vm.showCreateSheet = true }
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .refreshable { await vm.refresh() }
        .themeBackground()
        .navigationTitle("Now")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onSignOut()
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(Color.theme.mutedForeground)
                }
                .accessibilityLabel("Sign out")
            }
        }
    }
}

// MARK: - Create Playbook Sheet

/// Half-sheet for creating a playbook from the Now tab empty state.
private struct NowCreatePlaybookSheet: View {

    @Bindable var vm: NowTabViewModel
    @Environment(\.dismiss) private var dismiss

    private var isTitleEmpty: Bool {
        vm.newPlaybookTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TITLE")
                            .font(.theme.overline)
                            .foregroundStyle(Color.theme.mutedForeground)
                            .tracking(1.0)

                        TextField("My new playbook", text: $vm.newPlaybookTitle)
                            .font(.theme.bodyRegular)
                            .foregroundStyle(Color.theme.foreground)
                            .textInputAutocapitalization(.sentences)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.theme.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: .theme.radiusMd))
                            .overlay(
                                RoundedRectangle(cornerRadius: .theme.radiusMd)
                                    .stroke(Color.theme.input, lineWidth: 1)
                            )
                            .accessibilityLabel("Playbook title")
                            .accessibilityIdentifier("now_create_playbook_title")
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("DESCRIPTION")
                            .font(.theme.overline)
                            .foregroundStyle(Color.theme.mutedForeground)
                            .tracking(1.0)

                        Text("Optional")
                            .font(.theme.caption)
                            .foregroundStyle(Color.theme.mutedForeground)

                        TextField("What's this playbook about?", text: $vm.newPlaybookDescription, axis: .vertical)
                            .font(.theme.bodyRegular)
                            .foregroundStyle(Color.theme.foreground)
                            .lineLimit(3...6)
                            .textInputAutocapitalization(.sentences)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.theme.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: .theme.radiusMd))
                            .overlay(
                                RoundedRectangle(cornerRadius: .theme.radiusMd)
                                    .stroke(Color.theme.input, lineWidth: 1)
                            )
                            .accessibilityLabel("Playbook description, optional")
                    }

                    Button {
                        vm.createPlaybook()
                    } label: {
                        Text("Create")
                            .font(.theme.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.theme.primaryForeground)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 50)
                            .background(isTitleEmpty ? Color.theme.muted : Color.theme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: .theme.radiusMd))
                            .shadow(
                                color: isTitleEmpty ? .clear : Color.theme.primary.opacity(0.4),
                                radius: 12, y: 4
                            )
                    }
                    .buttonStyle(.pressable)
                    .disabled(isTitleEmpty)
                    .accessibilityLabel("Create playbook")
                    .accessibilityHint(isTitleEmpty ? "Enter a title first" : "Creates a new playbook")
                    .accessibilityIdentifier("now_create_playbook_submit")
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("New Playbook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        vm.newPlaybookTitle = ""
                        vm.newPlaybookDescription = ""
                        vm.showCreateSheet = false
                    }
                    .foregroundStyle(Color.theme.mutedForeground)
                }
            }
            .themeBackground()
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.theme.background)
    }
}
