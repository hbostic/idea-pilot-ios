//
//  SyncEngine.swift
//  idea-pilot
//
//  Orchestrates offline mutation queueing, background drain, and sync status.
//  Services call `enqueue()` when they detect offline conditions on write operations.
//  The engine drains the queue when connectivity is restored, the app foregrounds,
//  pull-to-refresh fires, or after a mutation (debounced 2s).
//

import Foundation
import SwiftData

/// The core offline-first sync orchestrator.
///
/// Coordinates between the `MutationQueue`, `NetworkMonitor`, and `APIClient`
/// to ensure offline mutations are persisted and replayed when connectivity
/// is available.
///
/// ## Drain Logic
/// 1. Entries are processed in FIFO order (by `createdAt`).
/// 2. Each entry is marked in-flight, then replayed via `APIClient.replayMutation()`.
/// 3. On success: POST creates are reconciled (temp ID → server ID), then the entry is removed.
/// 4. On retryable failure (offline, 500+): entry is marked failed with incremented retry count.
/// 5. On non-retryable failure (400, 404, session expired): entry is discarded.
///
/// ## Backoff
/// Failed entries use exponential backoff: `min(2^retryCount * 1s, 60s)`.
/// After `maxRetries` (default 5), the entry is permanently discarded.
@Observable
final class SyncEngine: @unchecked Sendable {

    // MARK: - Public State

    /// Observable sync status for UI indicators.
    let status: SyncStatus

    /// Observable network connectivity state.
    let networkMonitor: NetworkMonitor

    /// The persistent mutation queue.
    let mutationQueue: MutationQueue

    // MARK: - Dependencies

    private let apiClient: APIClient
    private let modelContainer: ModelContainer

    // MARK: - Configuration

    private let baseDelay: TimeInterval = 1.0
    private let maxDelay: TimeInterval = 60.0
    private let mutationDebounceInterval: TimeInterval = 2.0

    // MARK: - Internal State

    /// Timestamp of the last successful sync drain.
    var lastSyncDate: Date?

    private var isDraining = false
    private var debounceTask: Task<Void, Never>?

    /// JSON decoder matching the API contract (snake_case + ISO8601).
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// JSON encoder matching the API contract (snake_case + ISO8601).
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    // MARK: - Init

    /// Creates a SyncEngine.
    ///
    /// - Parameters:
    ///   - apiClient: The networking client for replaying mutations.
    ///   - modelContainer: The SwiftData container (shared with services).
    init(apiClient: APIClient, modelContainer: ModelContainer) {
        self.apiClient = apiClient
        self.modelContainer = modelContainer
        self.status = SyncStatus()
        self.networkMonitor = NetworkMonitor()
        self.mutationQueue = MutationQueue(modelContainer: modelContainer)
    }

    // MARK: - Lifecycle

    /// Starts the sync engine. Call once at app launch.
    ///
    /// Starts the network monitor, recovers any stale in-flight entries
    /// from a previous crash, and triggers an initial drain if connected.
    func start() {
        networkMonitor.onConnectivityRestored = { [weak self] in
            self?.triggerDrain()
        }
        networkMonitor.start()

        Task {
            try? mutationQueue.resetInFlightToPending()
            updateStatus()
            if networkMonitor.isConnected {
                triggerDrain()
            }
        }
    }

    /// Stops the sync engine. Call on sign-out.
    ///
    /// Stops the network monitor and purges the mutation queue.
    func stop() {
        networkMonitor.stop()
        debounceTask?.cancel()
        debounceTask = nil
        try? mutationQueue.purge()
        status.value = .synced
    }

    // MARK: - Enqueue

    /// Enqueues a mutation for later replay.
    ///
    /// Called by services when they catch `APIError.offline` or `.networkError`
    /// on a write operation. The mutation is silently added to the persistent
    /// queue and will be replayed when connectivity returns.
    ///
    /// - Parameters:
    ///   - path: The API endpoint path (e.g., `"/v1/tasks"`).
    ///   - method: The HTTP method.
    ///   - body: The Encodable request body (serialized to JSON Data internally).
    ///   - entityType: The domain entity type (e.g., `"task"`, `"playbook"`).
    ///   - entityId: Optional entity ID for create reconciliation.
    func enqueue(
        path: String,
        method: HTTPMethod,
        body: (any Encodable & Sendable)?,
        entityType: String,
        entityId: String? = nil
    ) {
        let bodyData: Data?
        if let body {
            bodyData = try? encoder.encode(body)
        } else {
            bodyData = nil
        }

        do {
            try mutationQueue.enqueue(
                path: path,
                method: method,
                bodyData: bodyData,
                entityType: entityType,
                entityId: entityId
            )
            updateStatus()
        } catch {
            #if DEBUG
            print("[SyncEngine] Failed to enqueue mutation: \(error)")
            #endif
        }
    }

    // MARK: - Triggers

    /// Triggers a drain when the app returns to the foreground.
    func onAppForeground() {
        guard networkMonitor.isConnected else { return }
        triggerDrain()
    }

    /// Triggers a drain from pull-to-refresh. Awaitable so `.refreshable` can use it.
    func onPullToRefresh() async {
        guard networkMonitor.isConnected else { return }
        await drain()
    }

    /// Triggers a drain after a mutation with a 2-second debounce.
    ///
    /// Multiple rapid mutations (e.g., reordering) coalesce into a single drain.
    func onMutationCompleted() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .seconds(mutationDebounceInterval))
            guard !Task.isCancelled else { return }
            await drain()
        }
    }

    /// Triggers a drain (fire-and-forget).
    func triggerDrain() {
        Task { await drain() }
    }

    // MARK: - Drain Logic

    /// Drains the mutation queue in FIFO order.
    ///
    /// Each mutation is replayed through `APIClient.replayMutation()`. On success,
    /// POST creates are reconciled (temp ID replaced with server ID), then the entry
    /// is removed. Failed entries are retried with exponential backoff.
    private func drain() async {
        guard !isDraining else { return }
        guard networkMonitor.isConnected else {
            updateStatus()
            return
        }

        isDraining = true
        status.value = .syncing

        do {
            while let entry = try mutationQueue.peek() {
                guard networkMonitor.isConnected else { break }

                // Respect exponential backoff.
                if let lastAttempt = entry.lastAttemptAt {
                    let backoff = min(pow(2.0, Double(entry.retryCount)) * baseDelay, maxDelay)
                    let nextAttemptAt = lastAttempt.addingTimeInterval(backoff)
                    if Date.now < nextAttemptAt {
                        break
                    }
                }

                try mutationQueue.markInFlight(entry)

                do {
                    let responseData = try await apiClient.replayMutation(
                        path: entry.endpointPath,
                        method: entry.httpMethod,
                        bodyData: entry.bodyData,
                        requiresAuth: true
                    )

                    // Reconcile POST creates (replace temp ID with server ID).
                    if entry.httpMethodRawValue == HTTPMethod.post.rawValue,
                       let tempId = entry.entityId {
                        try await reconcileCreate(
                            entityType: entry.entityType,
                            tempId: tempId,
                            responseData: responseData
                        )
                    }

                    try mutationQueue.remove(entry)
                } catch let error as APIError {
                    if isRetryable(error) {
                        try mutationQueue.markFailed(entry)
                    } else {
                        // Non-retryable (400, 404, session expired) — discard.
                        try mutationQueue.remove(entry)
                    }
                } catch {
                    try mutationQueue.markFailed(entry)
                }
            }
        } catch {
            #if DEBUG
            print("[SyncEngine] Drain error: \(error)")
            #endif
            status.value = .error(error.localizedDescription)
        }

        isDraining = false
        updateStatus()
        if case .synced = status.value {
            lastSyncDate = .now
        }
    }

    // MARK: - Create Reconciliation

    /// Reconciles a successfully replayed POST create mutation.
    ///
    /// Deletes the optimistic model (with temp ID) and inserts the
    /// server-truth model (with real server ID).
    private func reconcileCreate(entityType: String, tempId: String, responseData: Data) async throws {
        let context = modelContainer.mainContext

        switch entityType {
        case "task":
            let dto = try decoder.decode(TaskDTO.self, from: responseData)
            let predicate = #Predicate<TaskModel> { $0.id == tempId }
            var descriptor = FetchDescriptor(predicate: predicate)
            descriptor.fetchLimit = 1
            if let temp = try context.fetch(descriptor).first {
                context.delete(temp)
            }
            let model = dto.toModel()
            context.insert(model)
            try context.save()

        case "playbook":
            let dto = try decoder.decode(PlaybookDTO.self, from: responseData)
            let predicate = #Predicate<PlaybookModel> { $0.id == tempId }
            var descriptor = FetchDescriptor(predicate: predicate)
            descriptor.fetchLimit = 1
            if let temp = try context.fetch(descriptor).first {
                context.delete(temp)
            }
            let model = dto.toModel()
            context.insert(model)
            try context.save()

        case "weeklyCycle":
            let dto = try decoder.decode(WeeklyCycleDTO.self, from: responseData)
            let predicate = #Predicate<WeeklyCycleModel> { $0.id == tempId }
            var descriptor = FetchDescriptor(predicate: predicate)
            descriptor.fetchLimit = 1
            if let temp = try context.fetch(descriptor).first {
                context.delete(temp)
            }
            let model = dto.toModel()
            context.insert(model)
            try context.save()

        default:
            break
        }
    }

    // MARK: - Helpers

    /// Determines if an API error is retryable (worth keeping in the queue).
    private nonisolated func isRetryable(_ error: APIError) -> Bool {
        switch error {
        case .offline, .networkError:
            return true
        case .serverError(let code, _) where code >= 500:
            return true
        case .badRequest, .notFound, .sessionExpired, .decodingError:
            return false
        default:
            return false
        }
    }

    /// Updates the sync status based on current queue and connectivity state.
    private func updateStatus() {
        if !networkMonitor.isConnected {
            status.value = .offline
        } else if mutationQueue.pendingCount > 0 {
            status.value = .pending(mutationQueue.pendingCount)
        } else {
            status.value = .synced
        }
    }
}
