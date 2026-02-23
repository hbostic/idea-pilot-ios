//
//  PlaybookService.swift
//  idea-pilot
//
//  Service handling playbook API calls and SwiftData persistence.
//  Supports fetch (with incremental sync), create, and archive operations.
//

import Foundation
import SwiftData

// MARK: - PlaybookError

/// Errors specific to playbook operations.
nonisolated enum PlaybookError: Error, Equatable, Sendable {
    /// The requested playbook was not found (404).
    case notFound
    /// A network-level failure occurred.
    case networkError(String)
    /// The server returned an unexpected error.
    case serverError(String)
}

// MARK: - PlaybookServiceProtocol

/// Defines the playbook API surface for testability.
nonisolated protocol PlaybookServiceProtocol: Sendable {
    /// Fetches playbooks from the API, upserts into SwiftData, and returns the models.
    /// Falls back to cached SwiftData data when offline.
    func fetchPlaybooks(updatedSince: Date?) async throws -> [PlaybookModel]

    /// Creates a new playbook on the server and inserts it into SwiftData.
    func createPlaybook(title: String, description: String?) async throws -> PlaybookModel

    /// Archives a playbook on the server and updates SwiftData.
    func archivePlaybook(id: String) async throws
}

// MARK: - PlaybookService

/// Coordinates playbook CRUD through `APIClient` and SwiftData.
///
/// Each operation follows the pattern:
/// 1. Call the API endpoint
/// 2. Upsert/update SwiftData
/// 3. Return the model(s)
///
/// `fetchPlaybooks` supports offline fallback by reading from SwiftData cache
/// when the network is unavailable.
final class PlaybookService: PlaybookServiceProtocol, Sendable {

    private let apiClient: APIClient
    private let modelContainer: ModelContainer

    /// Creates a PlaybookService.
    ///
    /// - Parameters:
    ///   - apiClient: The networking client for API calls.
    ///   - modelContainer: The SwiftData container for local persistence.
    init(apiClient: APIClient, modelContainer: ModelContainer) {
        self.apiClient = apiClient
        self.modelContainer = modelContainer
    }

    func fetchPlaybooks(updatedSince: Date? = nil) async throws -> [PlaybookModel] {
        do {
            let dtos: [PlaybookDTO] = try await apiClient.request(.getPlaybooks(updatedSince: updatedSince))
            return try await upsertPlaybooks(dtos)
        } catch let error as APIError {
            if error.isOffline {
                return try await cachedPlaybooks()
            }
            throw mapError(error)
        } catch let error as PlaybookError {
            throw error
        } catch {
            throw PlaybookError.serverError(error.localizedDescription)
        }
    }

    func createPlaybook(title: String, description: String?) async throws -> PlaybookModel {
        let dto = CreatePlaybookDTO(title: title, description: description, phase: PlaybookPhase.proof.rawValue)
        do {
            let response: PlaybookDTO = try await apiClient.request(.createPlaybook(dto: dto))
            return try await insertPlaybook(response)
        } catch let error as APIError {
            throw mapError(error)
        } catch let error as PlaybookError {
            throw error
        } catch {
            throw PlaybookError.serverError(error.localizedDescription)
        }
    }

    func archivePlaybook(id: String) async throws {
        do {
            try await apiClient.requestVoid(.archivePlaybook(id: id))
            try await markArchived(id: id)
        } catch let error as APIError {
            throw mapError(error)
        } catch let error as PlaybookError {
            throw error
        } catch {
            throw PlaybookError.serverError(error.localizedDescription)
        }
    }

    // MARK: - Private — SwiftData Operations

    /// Upserts an array of playbook DTOs into SwiftData.
    @MainActor
    private func upsertPlaybooks(_ dtos: [PlaybookDTO]) throws -> [PlaybookModel] {
        let context = modelContainer.mainContext
        var models: [PlaybookModel] = []

        for dto in dtos {
            let predicate = #Predicate<PlaybookModel> { $0.id == dto.id }
            var descriptor = FetchDescriptor(predicate: predicate)
            descriptor.fetchLimit = 1

            if let existing = try context.fetch(descriptor).first {
                // Update existing model.
                existing.title = dto.title
                existing.descriptionText = dto.description
                existing.phaseRawValue = dto.phase
                existing.isArchived = dto.archivedAt != nil
                existing.updatedAt = dto.updatedAt
                models.append(existing)
            } else {
                // Insert new model.
                let model = dto.toModel()
                context.insert(model)
                models.append(model)
            }
        }

        try context.save()
        return models
    }

    /// Inserts a single playbook DTO into SwiftData.
    @MainActor
    private func insertPlaybook(_ dto: PlaybookDTO) throws -> PlaybookModel {
        let context = modelContainer.mainContext
        let model = dto.toModel()
        context.insert(model)
        try context.save()
        return model
    }

    /// Marks a playbook as archived in SwiftData.
    @MainActor
    private func markArchived(id: String) throws {
        let context = modelContainer.mainContext
        let predicate = #Predicate<PlaybookModel> { $0.id == id }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        guard let model = try context.fetch(descriptor).first else { return }
        model.isArchived = true
        try context.save()
    }

    /// Returns cached non-archived playbooks from SwiftData (offline fallback).
    @MainActor
    private func cachedPlaybooks() throws -> [PlaybookModel] {
        let context = modelContainer.mainContext
        let predicate = #Predicate<PlaybookModel> { $0.isArchived == false }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        return try context.fetch(descriptor)
    }

    // MARK: - Private — Error Mapping

    private func mapError(_ error: APIError) -> PlaybookError {
        switch error {
        case .notFound:
            return .notFound
        case .networkError(let urlError):
            return .networkError(urlError.localizedDescription)
        case .offline:
            return .networkError("No internet connection")
        case .serverError(_, let message):
            return .serverError(message ?? "Server error")
        case .badRequest(let message):
            return .serverError(message ?? "Bad request")
        case .sessionExpired:
            return .serverError("Session expired")
        case .decodingError(let message):
            return .serverError("Invalid response: \(message)")
        }
    }
}

// MARK: - APIError Offline Helper

extension APIError {

    /// Whether this error represents an offline/network condition.
    var isOffline: Bool {
        switch self {
        case .offline: return true
        case .networkError: return true
        default: return false
        }
    }
}
