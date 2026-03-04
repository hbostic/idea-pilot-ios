//
//  UITestMockServices.swift
//  idea-pilot
//
//  Mock services injected when the app launches with UI_TEST_MODE.
//  Provides deterministic data for E2E UI tests.
//

#if DEBUG

import Foundation

// MARK: - Mock Keychain

/// In-memory Keychain replacement for UI test mode.
nonisolated final class UITestMockKeychainService: KeychainStorable, @unchecked Sendable {

    nonisolated(unsafe) var storage: [String: String] = [:]

    func save(_ value: String, forKey key: String) throws {
        storage[key] = value
    }

    func load(forKey key: String) throws -> String? {
        storage[key]
    }

    func delete(forKey key: String) throws {
        storage.removeValue(forKey: key)
    }
}

// MARK: - Mock Auth Service

/// Always-succeeding auth service for UI tests.
final class UITestAuthService: AuthServiceProtocol, Sendable {

    private let tokenManager: TokenManager

    init(tokenManager: TokenManager) {
        self.tokenManager = tokenManager
    }

    func login(email: String, password: String) async throws -> UserSession {
        let session = UserSession(
            userId: "uitest-1",
            email: email,
            accessToken: "test-access",
            refreshToken: "test-refresh"
        )
        try await tokenManager.storeSession(session)
        return session
    }

    func register(email: String, password: String) async throws -> UserSession {
        try await login(email: email, password: password)
    }

    func auth0Login(idToken: String) async throws -> UserSession {
        try await login(email: "test@example.com", password: "")
    }

    func logout() async throws {
        await tokenManager.clearTokens()
    }
}

// MARK: - Mock Playbook Service

/// Returns a single "Side Project" playbook for UI tests.
struct UITestPlaybookService: PlaybookServiceProtocol {

    nonisolated func fetchPlaybooks(updatedSince: Date?) async throws -> [PlaybookModel] {
        [PlaybookModel(id: "pb-uitest", title: "Side Project", phase: .proof)]
    }

    nonisolated func createPlaybook(title: String, description: String?) async throws -> PlaybookModel {
        PlaybookModel(id: "pb-new-\(UUID().uuidString.prefix(8))", title: title)
    }

    nonisolated func archivePlaybook(id: String) async throws {}
}

// MARK: - Mock Task Service

/// Returns deterministic tasks for UI tests: 1 in Now, 2 in Next.
struct UITestTaskService: TaskServiceProtocol {

    nonisolated func fetchTasks(playbookId: String, lane: TaskLane?, updatedSince: Date?) async throws -> [TaskModel] {
        let tasks = [
            TaskModel(
                id: "t-now-1",
                playbookId: playbookId,
                title: "Design landing page",
                lane: .now,
                estimatedMinutes: 60,
                orderIndex: 0
            ),
            TaskModel(
                id: "t-next-1",
                playbookId: playbookId,
                title: "Research competitors",
                lane: .next,
                estimatedMinutes: 90,
                orderIndex: 0
            ),
            TaskModel(
                id: "t-next-2",
                playbookId: playbookId,
                title: "Write copy",
                lane: .next,
                estimatedMinutes: 30,
                orderIndex: 1
            ),
        ]

        if let lane {
            return tasks.filter { $0.lane == lane }
        }
        return tasks
    }

    nonisolated func createTask(playbookId: String, title: String, detail: String?, lane: TaskLane, estimatedMinutes: Int) async throws -> TaskModel {
        TaskModel(
            id: "t-new-\(UUID().uuidString.prefix(8))",
            playbookId: playbookId,
            title: title,
            detail: detail,
            lane: lane,
            estimatedMinutes: estimatedMinutes,
            orderIndex: 99
        )
    }

    nonisolated func updateTask(id: String, dto: UpdateTaskDTO) async throws -> TaskModel {
        TaskModel(playbookId: "pb-uitest", title: dto.title ?? "Updated")
    }

    nonisolated func completeTask(id: String) async throws -> TaskModel {
        TaskModel(
            id: id,
            playbookId: "pb-uitest",
            title: "Completed",
            status: .done,
            completedAt: .now
        )
    }

    nonisolated func reorderTasks(playbookId: String, lane: TaskLane, taskIds: [String]) async throws {}

    nonisolated func deleteTask(id: String) async throws {}
}

// MARK: - Mock Section Service

/// Returns empty sections for UI tests.
struct UITestSectionService: SectionServiceProtocol {

    nonisolated func fetchSections(playbookId: String, updatedSince: Date?) async throws -> [SectionModel] { [] }

    nonisolated func updateSection(playbookId: String, sectionType: SectionType, content: String) async throws -> SectionModel {
        SectionModel(playbookId: playbookId, sectionType: sectionType, content: content)
    }
}

// MARK: - Mock Weekly Plan Service

/// Returns a fresh weekly cycle for UI tests.
struct UITestWeeklyPlanService: WeeklyPlanServiceProtocol {

    nonisolated func getWeeklyStatus(playbookId: String) async throws -> WeeklyCycleModel {
        WeeklyCycleModel(playbookId: playbookId, weekStartDate: .now)
    }

    nonisolated func createWeeklyPlan(playbookId: String, taskIds: [String]) async throws -> WeeklyCycleModel {
        WeeklyCycleModel(
            playbookId: playbookId,
            weekStartDate: .now,
            totalCount: taskIds.count
        )
    }

    nonisolated func fetchWeeklyCycles(playbookId: String) async throws -> [WeeklyCycleModel] { [] }
}

#endif
