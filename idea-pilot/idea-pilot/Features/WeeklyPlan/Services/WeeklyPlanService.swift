//
//  WeeklyPlanService.swift
//  idea-pilot
//
//  Service handling weekly plan API calls and SwiftData persistence.
//  Supports fetching weekly cycles, getting status, and creating plans.
//

import Foundation
import SwiftData

// MARK: - WeeklyPlanError

/// Errors specific to weekly plan operations.
nonisolated enum WeeklyPlanError: Error, Equatable, Sendable {
    /// The requested resource was not found (404).
    case notFound
    /// A network-level failure occurred.
    case networkError(String)
    /// The server returned an unexpected error.
    case serverError(String)
}

// MARK: - WeeklyPlanServiceProtocol

/// Defines the weekly plan API surface for testability.
nonisolated protocol WeeklyPlanServiceProtocol: Sendable {
    /// Fetches the current week's completion status for a playbook.
    func getWeeklyStatus(playbookId: String) async throws -> WeeklyCycleModel

    /// Creates a weekly plan by promoting the given tasks to Now.
    func createWeeklyPlan(playbookId: String, taskIds: [String]) async throws -> WeeklyCycleModel

    /// Fetches all weekly cycles for a playbook.
    /// Falls back to cached SwiftData data when offline.
    func fetchWeeklyCycles(playbookId: String) async throws -> [WeeklyCycleModel]
}

// MARK: - WeeklyPlanService

/// Coordinates weekly plan operations through `APIClient` and SwiftData.
///
/// Each operation follows the standard pattern:
/// Call the API → update SwiftData → return model(s).
///
/// `fetchWeeklyCycles` supports offline fallback by reading from SwiftData cache
/// when the network is unavailable.
final class WeeklyPlanService: WeeklyPlanServiceProtocol, Sendable {

    private let apiClient: APIClient
    private let modelContainer: ModelContainer
    private let syncEngine: SyncEngine?

    /// Creates a WeeklyPlanService.
    ///
    /// - Parameters:
    ///   - apiClient: The networking client for API calls.
    ///   - modelContainer: The SwiftData container for local persistence.
    ///   - syncEngine: Optional sync engine for offline mutation queueing.
    init(apiClient: APIClient, modelContainer: ModelContainer, syncEngine: SyncEngine? = nil) {
        self.apiClient = apiClient
        self.modelContainer = modelContainer
        self.syncEngine = syncEngine
    }

    func getWeeklyStatus(playbookId: String) async throws -> WeeklyCycleModel {
        do {
            let dto: WeeklyCycleDTO = try await apiClient.request(
                .getWeeklyStatus(playbookId: playbookId)
            )
            return try await upsertSingleCycle(dto)
        } catch let error as APIError {
            throw mapError(error)
        } catch let error as WeeklyPlanError {
            throw error
        } catch {
            throw WeeklyPlanError.serverError(error.localizedDescription)
        }
    }

    func createWeeklyPlan(playbookId: String, taskIds: [String]) async throws -> WeeklyCycleModel {
        let dto = CreateWeeklyPlanDTO(taskIds: taskIds)
        do {
            let response: WeeklyCycleDTO = try await apiClient.request(
                .createWeeklyPlan(playbookId: playbookId, dto: dto)
            )
            return try await upsertSingleCycle(response)
        } catch let error as APIError where error.isOffline {
            if let syncEngine {
                let tempModel = try await insertOptimisticCycle(playbookId: playbookId, taskCount: taskIds.count)
                await syncEngine.enqueue(
                    path: "/v1/playbooks/\(playbookId)/weekly/plan",
                    method: .post,
                    body: dto,
                    entityType: "weeklyCycle",
                    entityId: tempModel.id
                )
                return tempModel
            }
            throw mapError(error)
        } catch let error as APIError {
            throw mapError(error)
        } catch let error as WeeklyPlanError {
            throw error
        } catch {
            throw WeeklyPlanError.serverError(error.localizedDescription)
        }
    }

    func fetchWeeklyCycles(playbookId: String) async throws -> [WeeklyCycleModel] {
        do {
            let dtos: [WeeklyCycleDTO] = try await apiClient.request(
                .getWeeklyCycles(playbookId: playbookId)
            )
            return try await upsertCycles(dtos)
        } catch let error as APIError {
            if error.isOffline {
                return try await cachedWeeklyCycles(playbookId: playbookId)
            }
            throw mapError(error)
        } catch let error as WeeklyPlanError {
            throw error
        } catch {
            throw WeeklyPlanError.serverError(error.localizedDescription)
        }
    }

    // MARK: - Private — SwiftData Operations

    /// Upserts an array of weekly cycle DTOs into SwiftData.
    @MainActor
    private func upsertCycles(_ dtos: [WeeklyCycleDTO]) throws -> [WeeklyCycleModel] {
        let context = modelContainer.mainContext
        var models: [WeeklyCycleModel] = []

        for dto in dtos {
            let cycleId = dto.id

            let predicate = #Predicate<WeeklyCycleModel> { $0.id == cycleId }
            var descriptor = FetchDescriptor(predicate: predicate)
            descriptor.fetchLimit = 1

            if let existing = try context.fetch(descriptor).first {
                existing.completedCount = dto.completedCount
                existing.totalCount = dto.totalCount
                existing.weekStartDate = dto.weekStartDate
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

    /// Upserts a single weekly cycle DTO into SwiftData.
    @MainActor
    private func upsertSingleCycle(_ dto: WeeklyCycleDTO) throws -> WeeklyCycleModel {
        try upsertCycles([dto]).first!
    }

    /// Inserts an optimistic weekly cycle with a temp ID for offline creates.
    @MainActor
    private func insertOptimisticCycle(playbookId: String, taskCount: Int) throws -> WeeklyCycleModel {
        let context = modelContainer.mainContext
        let model = WeeklyCycleModel(
            playbookId: playbookId,
            weekStartDate: .now,
            totalCount: taskCount
        )
        context.insert(model)
        try context.save()
        return model
    }

    /// Returns cached weekly cycles from SwiftData (offline fallback).
    @MainActor
    private func cachedWeeklyCycles(playbookId: String) throws -> [WeeklyCycleModel] {
        let context = modelContainer.mainContext
        let predicate = #Predicate<WeeklyCycleModel> { $0.playbookId == playbookId }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try context.fetch(descriptor)
    }

    // MARK: - Private — Error Mapping

    private func mapError(_ error: APIError) -> WeeklyPlanError {
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
