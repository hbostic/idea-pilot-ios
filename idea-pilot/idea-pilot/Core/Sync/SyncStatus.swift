//
//  SyncStatus.swift
//  idea-pilot
//
//  Observable sync status for UI display.
//  Views observe `SyncStatus.value` to show sync indicators
//  (green/synced, yellow/pending, animated/syncing, red/error, grey/offline).
//

import Foundation

// MARK: - SyncStatusValue

/// The current synchronization state of the mutation queue.
///
/// Used by views to display sync indicators:
/// - `.synced` — all mutations sent, connected (green)
/// - `.syncing` — drain in progress (animated)
/// - `.pending(count)` — mutations waiting to send (yellow)
/// - `.error(message)` — last drain attempt failed (red)
/// - `.offline` — no network connectivity (grey)
nonisolated enum SyncStatusValue: Equatable, Sendable {
    /// Queue is empty and device is connected.
    case synced
    /// Currently draining the mutation queue.
    case syncing
    /// Mutations are queued and waiting for connectivity or drain.
    case pending(Int)
    /// The last drain attempt encountered an error.
    case error(String)
    /// Device has no network connectivity.
    case offline
}

// MARK: - SyncStatus

/// Observable container for the current sync status.
///
/// Any view can observe this to show sync indicators.
/// Updated by `SyncEngine` as the queue state changes.
@Observable
final class SyncStatus {
    /// The current sync status value.
    var value: SyncStatusValue = .synced
}
