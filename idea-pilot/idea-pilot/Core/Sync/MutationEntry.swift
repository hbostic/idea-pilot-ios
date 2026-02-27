//
//  MutationEntry.swift
//  idea-pilot
//
//  SwiftData model representing a queued offline mutation.
//  Each entry stores enough information to replay the API request
//  when connectivity is restored.
//

import Foundation
import SwiftData

// MARK: - MutationStatus

/// The lifecycle state of a queued mutation.
nonisolated enum MutationStatus: String, Sendable {
    /// Waiting to be sent.
    case pending
    /// Currently being sent by the SyncEngine.
    case inFlight
}

// MARK: - MutationEntry

/// A queued offline mutation persisted in SwiftData.
///
/// Stores the endpoint path, HTTP method, pre-encoded JSON body,
/// entity metadata, and retry state. The `SyncEngine` drains these
/// entries in FIFO order (by `createdAt`) when connectivity is available.
///
/// Body data is pre-encoded at enqueue time using snake_case + ISO8601
/// to match the API contract, avoiding double-encoding on replay.
@Model
final class MutationEntry {

    /// Unique identifier for this queue entry.
    @Attribute(.unique) var id: String

    /// The API endpoint path (e.g., `"/v1/tasks"`).
    var endpointPath: String

    /// The HTTP method raw value (e.g., `"POST"`, `"PATCH"`).
    var httpMethodRawValue: String

    /// Pre-encoded JSON request body, or `nil` for bodyless requests.
    var bodyData: Data?

    /// The domain entity type (e.g., `"task"`, `"playbook"`, `"section"`).
    var entityType: String

    /// The entity ID (server ID for updates/deletes, temp ID for creates).
    var entityId: String?

    /// Number of failed replay attempts.
    var retryCount: Int

    /// Maximum allowed retries before the entry is discarded.
    var maxRetries: Int

    /// Timestamp of creation, used for FIFO ordering.
    var createdAt: Date

    /// Timestamp of the last replay attempt, used for backoff calculation.
    var lastAttemptAt: Date?

    /// Current lifecycle state raw value.
    var statusRawValue: String

    /// The current lifecycle state.
    var status: MutationStatus {
        get { MutationStatus(rawValue: statusRawValue) ?? .pending }
        set { statusRawValue = newValue.rawValue }
    }

    /// The HTTP method.
    var httpMethod: HTTPMethod {
        HTTPMethod(rawValue: httpMethodRawValue) ?? .post
    }

    init(
        id: String = UUID().uuidString,
        endpointPath: String,
        httpMethod: HTTPMethod,
        bodyData: Data? = nil,
        entityType: String,
        entityId: String? = nil,
        retryCount: Int = 0,
        maxRetries: Int = 5,
        createdAt: Date = .now,
        lastAttemptAt: Date? = nil,
        status: MutationStatus = .pending
    ) {
        self.id = id
        self.endpointPath = endpointPath
        self.httpMethodRawValue = httpMethod.rawValue
        self.bodyData = bodyData
        self.entityType = entityType
        self.entityId = entityId
        self.retryCount = retryCount
        self.maxRetries = maxRetries
        self.createdAt = createdAt
        self.lastAttemptAt = lastAttemptAt
        self.statusRawValue = status.rawValue
    }
}
