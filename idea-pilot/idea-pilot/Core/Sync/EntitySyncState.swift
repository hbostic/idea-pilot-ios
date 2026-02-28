//
//  EntitySyncState.swift
//  idea-pilot
//
//  Per-entity sync state for optimistic update visual indicators.
//  Used by views to show pending/failed indicators on individual items.
//

import Foundation

/// The sync state of a specific entity (task, playbook, section, etc.)
/// as observed by the UI for per-item indicators.
///
/// Derived from the `MutationQueue`'s knowledge of pending entries.
/// Views use this to show subtle sync/warning icons on affected items.
enum EntitySyncState: Equatable, Sendable {
    /// One or more mutations are queued and waiting to send.
    case pending
    /// A mutation is actively being sent to the server.
    case inFlight
    /// The last sync attempt failed. `retryCount` indicates how many
    /// times the mutation has been retried.
    case failed(retryCount: Int)
}
