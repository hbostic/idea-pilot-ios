//
//  SyncStatusDotView.swift
//  idea-pilot
//
//  A small colored dot that reflects the current sync status.
//  Used in the Playbook Home nav bar and anywhere else a compact
//  sync indicator is needed.
//

import SwiftUI

/// A compact sync status indicator rendered as a small colored dot.
///
/// States:
/// - `.synced` — green dot
/// - `.syncing` — spinning progress indicator
/// - `.pending` — yellow dot
/// - `.error` — red dot
/// - `.offline` — gray dot
struct SyncStatusDotView: View {

    let status: SyncStatusValue
    var size: CGFloat = 8

    var body: some View {
        switch status {
        case .synced:
            Circle()
                .fill(Color.green)
                .frame(width: size, height: size)
        case .syncing:
            ProgressView()
                .scaleEffect(0.6)
                .frame(width: size + 4, height: size + 4)
                .tint(Color.theme.primary)
        case .pending:
            Circle()
                .fill(Color.yellow)
                .frame(width: size, height: size)
        case .error:
            Circle()
                .fill(Color.theme.destructive)
                .frame(width: size, height: size)
        case .offline:
            Circle()
                .fill(Color.gray)
                .frame(width: size, height: size)
        }
    }

    /// A human-readable label describing the current status.
    var statusLabel: String {
        switch status {
        case .synced: "Synced"
        case .syncing: "Syncing"
        case .pending(let count): "\(count) pending"
        case .error: "Sync error"
        case .offline: "Offline"
        }
    }
}
