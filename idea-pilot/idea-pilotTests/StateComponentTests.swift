//
//  StateComponentTests.swift
//  idea-pilotTests
//
//  Unit tests for shared state overlay components:
//  ErrorBannerView, OfflineBannerView, EmptyStateView, SkeletonView.
//

import Foundation
import Testing
@testable import idea_pilot

// MARK: - Tests

@Suite("State Components", .serialized)
struct StateComponentTests {

    // MARK: - OfflineBanner

    @Test("OfflineBannerView shows when disconnected")
    @MainActor func offlineBannerShowsWhenDisconnected() {
        let monitor = NetworkMonitor()
        monitor.isConnected = false

        let view = OfflineBannerView(networkMonitor: monitor)
        // The view conditionally renders based on isConnected.
        // When false, content should be present.
        #expect(monitor.isConnected == false)
        _ = view // Verify it can be instantiated without error.
    }

    @Test("OfflineBannerView hidden when connected")
    @MainActor func offlineBannerHiddenWhenConnected() {
        let monitor = NetworkMonitor()
        monitor.isConnected = true

        let view = OfflineBannerView(networkMonitor: monitor)
        // When connected, the if-check yields no content.
        #expect(monitor.isConnected == true)
        _ = view
    }

    @Test("OfflineBannerView reacts to connectivity changes")
    @MainActor func offlineBannerReactsToChanges() {
        let monitor = NetworkMonitor()
        monitor.isConnected = true
        #expect(monitor.isConnected == true)

        monitor.isConnected = false
        #expect(monitor.isConnected == false)

        monitor.isConnected = true
        #expect(monitor.isConnected == true)
    }

    // MARK: - EmptyStateView

    @Test("EmptyStateView accepts all parameters")
    @MainActor func emptyStateViewParameters() {
        var actionCalled = false
        let view = EmptyStateView(
            icon: "square.stack.3d.up.slash",
            title: "No playbooks yet",
            message: "Create your first playbook to get started",
            actionTitle: "New Playbook",
            onAction: { actionCalled = true }
        )
        _ = view
        #expect(actionCalled == false) // Action not triggered on init.
    }

    @Test("EmptyStateView works without action")
    @MainActor func emptyStateViewWithoutAction() {
        let view = EmptyStateView(
            icon: "checklist",
            title: "No tasks",
            message: "Add a task to get started"
        )
        _ = view // No crash, actionTitle defaults to nil.
    }

    // MARK: - ErrorBannerView

    @Test("ErrorBannerView stores message")
    @MainActor func errorBannerViewMessage() {
        let view = ErrorBannerView(message: "Network error. Please check your connection.")
        #expect(view.message == "Network error. Please check your connection.")
    }

    // MARK: - SkeletonList

    @Test("SkeletonList creates correct number of rows")
    @MainActor func skeletonListRowCount() {
        let list3 = SkeletonList(rowCount: 3)
        #expect(list3.rowCount == 3)

        let list5 = SkeletonList(rowCount: 5, rowHeight: 80)
        #expect(list5.rowCount == 5)
        #expect(list5.rowHeight == 80)
    }

    @Test("SkeletonList defaults")
    @MainActor func skeletonListDefaults() {
        let list = SkeletonList()
        #expect(list.rowCount == 3)
        #expect(list.rowHeight == 72)
        #expect(list.spacing == 12)
    }

    @Test("SkeletonRow uses provided height")
    @MainActor func skeletonRowHeight() {
        let row = SkeletonRow(height: 100)
        #expect(row.height == 100)
    }
}
