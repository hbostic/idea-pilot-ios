//
//  MutationQueue.swift
//  idea-pilot
//
//  Persistent FIFO queue of offline mutations backed by SwiftData.
//  All mutations are stored as MutationEntry models in the same
//  ModelContainer used by the rest of the app. The queue persists
//  across app launches.
//

import Foundation
import SwiftData

/// A persistent FIFO queue of offline mutations backed by SwiftData.
///
/// The `SyncEngine` drives this queue: enqueuing mutations when services
/// detect offline conditions, and draining entries when connectivity
/// is available.
///
/// All SwiftData operations run on `@MainActor` (project default).
@Observable
final class MutationQueue {

    private let modelContainer: ModelContainer

    /// The number of pending mutations in the queue (observable by views).
    var pendingCount: Int = 0

    /// Creates a MutationQueue.
    ///
    /// - Parameter modelContainer: The SwiftData container for persistence.
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - Enqueue

    /// Enqueues a mutation for later replay.
    ///
    /// - Parameters:
    ///   - path: The API endpoint path.
    ///   - method: The HTTP method.
    ///   - bodyData: Pre-encoded JSON body data.
    ///   - entityType: The domain entity type (e.g., "task").
    ///   - entityId: Optional entity ID for reconciliation.
    func enqueue(
        path: String,
        method: HTTPMethod,
        bodyData: Data?,
        entityType: String,
        entityId: String?
    ) throws {
        let context = modelContainer.mainContext
        let entry = MutationEntry(
            endpointPath: path,
            httpMethod: method,
            bodyData: bodyData,
            entityType: entityType,
            entityId: entityId
        )
        context.insert(entry)
        try context.save()
        refreshPendingCount()
    }

    // MARK: - Peek / Fetch

    /// Returns the next pending mutation in FIFO order, or `nil` if empty.
    func peek() throws -> MutationEntry? {
        let context = modelContainer.mainContext
        let statusRaw = MutationStatus.pending.rawValue
        let predicate = #Predicate<MutationEntry> { $0.statusRawValue == statusRaw }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.createdAt)])
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Returns all pending mutations in FIFO order.
    func allPending() throws -> [MutationEntry] {
        let context = modelContainer.mainContext
        let statusRaw = MutationStatus.pending.rawValue
        let predicate = #Predicate<MutationEntry> { $0.statusRawValue == statusRaw }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.createdAt)])
        return try context.fetch(descriptor)
    }

    // MARK: - State Transitions

    /// Marks a mutation as in-flight (currently being sent).
    func markInFlight(_ entry: MutationEntry) throws {
        entry.status = .inFlight
        try modelContainer.mainContext.save()
    }

    /// Removes a successfully sent mutation from the queue.
    func remove(_ entry: MutationEntry) throws {
        let context = modelContainer.mainContext
        context.delete(entry)
        try context.save()
        refreshPendingCount()
    }

    /// Marks a mutation as failed and increments its retry count.
    ///
    /// If the retry count exceeds `maxRetries`, the entry is permanently
    /// removed from the queue (discarded).
    func markFailed(_ entry: MutationEntry) throws {
        entry.retryCount += 1
        entry.lastAttemptAt = .now
        if entry.retryCount >= entry.maxRetries {
            let context = modelContainer.mainContext
            context.delete(entry)
            try context.save()
        } else {
            entry.status = .pending
            try modelContainer.mainContext.save()
        }
        refreshPendingCount()
    }

    // MARK: - Recovery

    /// Resets any in-flight mutations back to pending.
    ///
    /// Called at app launch to recover from a crash during drain.
    /// Entries that were mid-flight when the app terminated are
    /// returned to the pending state for retry.
    func resetInFlightToPending() throws {
        let context = modelContainer.mainContext
        let statusRaw = MutationStatus.inFlight.rawValue
        let predicate = #Predicate<MutationEntry> { $0.statusRawValue == statusRaw }
        let descriptor = FetchDescriptor(predicate: predicate)
        let stale = try context.fetch(descriptor)
        for entry in stale {
            entry.status = .pending
        }
        if !stale.isEmpty {
            try context.save()
        }
        refreshPendingCount()
    }

    /// Removes all entries from the queue.
    ///
    /// Called on sign-out to clear any pending mutations.
    func purge() throws {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<MutationEntry>()
        let all = try context.fetch(descriptor)
        for entry in all {
            context.delete(entry)
        }
        if !all.isEmpty {
            try context.save()
        }
        pendingCount = 0
    }

    // MARK: - Private

    private func refreshPendingCount() {
        let context = modelContainer.mainContext
        let statusRaw = MutationStatus.pending.rawValue
        let predicate = #Predicate<MutationEntry> { $0.statusRawValue == statusRaw }
        let descriptor = FetchDescriptor(predicate: predicate)
        pendingCount = (try? context.fetchCount(descriptor)) ?? 0
    }
}
