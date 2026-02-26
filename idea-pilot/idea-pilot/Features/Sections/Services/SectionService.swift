//
//  SectionService.swift
//  idea-pilot
//
//  Service handling section API calls and SwiftData persistence.
//  Supports fetch (with incremental sync) and update operations.
//

import Foundation
import SwiftData

// MARK: - SectionError

/// Errors specific to section operations.
nonisolated enum SectionError: Error, Equatable, Sendable {
    /// The requested section was not found (404).
    case notFound
    /// A network-level failure occurred.
    case networkError(String)
    /// The server returned an unexpected error.
    case serverError(String)
}

// MARK: - SectionServiceProtocol

/// Defines the section API surface for testability.
nonisolated protocol SectionServiceProtocol: Sendable {
    /// Fetches sections from the API, upserts into SwiftData, and returns the models.
    /// Falls back to cached SwiftData data when offline.
    func fetchSections(playbookId: String, updatedSince: Date?) async throws -> [SectionModel]

    /// Updates section content on the server and in SwiftData.
    func updateSection(playbookId: String, sectionType: SectionType, content: String) async throws -> SectionModel
}

// MARK: - SectionService

/// Coordinates section CRUD through `APIClient` and SwiftData.
///
/// Each operation follows the standard pattern:
/// Call the API → update SwiftData → return model(s).
///
/// `fetchSections` supports offline fallback by reading from SwiftData cache
/// when the network is unavailable.
final class SectionService: SectionServiceProtocol, Sendable {

    private let apiClient: APIClient
    private let modelContainer: ModelContainer

    /// Creates a SectionService.
    ///
    /// - Parameters:
    ///   - apiClient: The networking client for API calls.
    ///   - modelContainer: The SwiftData container for local persistence.
    init(apiClient: APIClient, modelContainer: ModelContainer) {
        self.apiClient = apiClient
        self.modelContainer = modelContainer
    }

    func fetchSections(playbookId: String, updatedSince: Date? = nil) async throws -> [SectionModel] {
        do {
            let dtos: [SectionDTO] = try await apiClient.request(
                .getSections(playbookId: playbookId, updatedSince: updatedSince)
            )
            return try await upsertSections(dtos)
        } catch let error as APIError {
            if error.isOffline {
                return try await cachedSections(playbookId: playbookId)
            }
            throw mapError(error)
        } catch let error as SectionError {
            throw error
        } catch {
            throw SectionError.serverError(error.localizedDescription)
        }
    }

    func updateSection(playbookId: String, sectionType: SectionType, content: String) async throws -> SectionModel {
        do {
            let dto = UpdateSectionDTO(content: content)
            let response: SectionDTO = try await apiClient.request(
                .updateSection(playbookId: playbookId, sectionType: sectionType.rawValue, dto: dto)
            )
            return try await upsertSingleSection(response)
        } catch let error as APIError {
            throw mapError(error)
        } catch let error as SectionError {
            throw error
        } catch {
            throw SectionError.serverError(error.localizedDescription)
        }
    }

    // MARK: - Private — SwiftData Operations

    /// Upserts an array of section DTOs into SwiftData.
    @MainActor
    private func upsertSections(_ dtos: [SectionDTO]) throws -> [SectionModel] {
        let context = modelContainer.mainContext
        var models: [SectionModel] = []

        for dto in dtos {
            let compositeId = "\(dto.playbookId)_\(dto.sectionType)"

            let predicate = #Predicate<SectionModel> { $0.compositeId == compositeId }
            var descriptor = FetchDescriptor(predicate: predicate)
            descriptor.fetchLimit = 1

            if let existing = try context.fetch(descriptor).first {
                existing.content = dto.content
                existing.updatedAt = dto.updatedAt
                models.append(existing)
            } else {
                let model = dto.toModel()
                context.insert(model)
                models.append(model)
            }
        }

        try context.save()
        return models
    }

    /// Upserts a single section DTO into SwiftData.
    @MainActor
    private func upsertSingleSection(_ dto: SectionDTO) throws -> SectionModel {
        try upsertSections([dto]).first!
    }

    /// Returns cached sections from SwiftData (offline fallback).
    @MainActor
    private func cachedSections(playbookId: String) throws -> [SectionModel] {
        let context = modelContainer.mainContext
        let predicate = #Predicate<SectionModel> { $0.playbookId == playbookId }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try context.fetch(descriptor)
    }

    // MARK: - Private — Error Mapping

    private func mapError(_ error: APIError) -> SectionError {
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
