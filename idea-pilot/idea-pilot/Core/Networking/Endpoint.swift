//
//  Endpoint.swift
//  idea-pilot
//
//  Typed API endpoint definitions with static factory methods.
//

import Foundation

/// A type-safe description of an API request.
///
/// Endpoints are value types that describe *what* to request — the path, HTTP method,
/// body, and query parameters. `APIClient` uses these to build `URLRequest` objects.
///
/// Use the static factory methods instead of constructing directly:
/// ```swift
/// let playbooks: [PlaybookDTO] = try await client.request(.getPlaybooks())
/// ```
nonisolated struct Endpoint: Sendable {

    /// The URL path relative to the base URL (e.g., `"/v1/playbooks"`).
    let path: String

    /// The HTTP method.
    let method: HTTPMethod

    /// The JSON-encodable request body, or `nil` for bodyless requests.
    let body: (any Encodable & Sendable)?

    /// Optional query parameters.
    let queryItems: [URLQueryItem]?

    /// Whether this endpoint requires authentication (default: `true`).
    let requiresAuth: Bool

    init(
        path: String,
        method: HTTPMethod,
        body: (any Encodable & Sendable)? = nil,
        queryItems: [URLQueryItem]? = nil,
        requiresAuth: Bool = true
    ) {
        self.path = path
        self.method = method
        self.body = body
        self.queryItems = queryItems
        self.requiresAuth = requiresAuth
    }
}

// MARK: - Auth Endpoints

extension Endpoint {

    static func login(dto: LoginRequestDTO) -> Endpoint {
        Endpoint(path: "/v1/auth/login", method: .post, body: dto, requiresAuth: false)
    }

    static func refreshToken(dto: RefreshTokenRequestDTO) -> Endpoint {
        Endpoint(path: "/v1/auth/refresh", method: .post, body: dto, requiresAuth: false)
    }
}

// MARK: - Playbook Endpoints

extension Endpoint {

    static func getPlaybooks() -> Endpoint {
        Endpoint(path: "/v1/playbooks", method: .get)
    }

    static func getPlaybook(id: String) -> Endpoint {
        Endpoint(path: "/v1/playbooks/\(id)", method: .get)
    }

    static func createPlaybook(dto: CreatePlaybookDTO) -> Endpoint {
        Endpoint(path: "/v1/playbooks", method: .post, body: dto)
    }

    static func updatePlaybook(id: String, dto: UpdatePlaybookDTO) -> Endpoint {
        Endpoint(path: "/v1/playbooks/\(id)", method: .patch, body: dto)
    }

    static func deletePlaybook(id: String) -> Endpoint {
        Endpoint(path: "/v1/playbooks/\(id)", method: .delete)
    }
}

// MARK: - Task Endpoints

extension Endpoint {

    static func getTasks(playbookId: String) -> Endpoint {
        Endpoint(path: "/v1/playbooks/\(playbookId)/tasks", method: .get)
    }

    static func createTask(dto: CreateTaskDTO) -> Endpoint {
        Endpoint(path: "/v1/tasks", method: .post, body: dto)
    }

    static func updateTask(id: String, dto: UpdateTaskDTO) -> Endpoint {
        Endpoint(path: "/v1/tasks/\(id)", method: .patch, body: dto)
    }

    static func deleteTask(id: String) -> Endpoint {
        Endpoint(path: "/v1/tasks/\(id)", method: .delete)
    }

    static func reorderTasks(dto: ReorderTasksDTO) -> Endpoint {
        Endpoint(path: "/v1/tasks/reorder", method: .post, body: dto)
    }
}

// MARK: - Section Endpoints

extension Endpoint {

    static func getSections(playbookId: String) -> Endpoint {
        Endpoint(path: "/v1/playbooks/\(playbookId)/sections", method: .get)
    }

    static func updateSection(playbookId: String, sectionType: String, dto: UpdateSectionDTO) -> Endpoint {
        Endpoint(path: "/v1/playbooks/\(playbookId)/sections/\(sectionType)", method: .put, body: dto)
    }
}

// MARK: - Weekly Cycle Endpoints

extension Endpoint {

    static func getWeeklyCycles(playbookId: String) -> Endpoint {
        Endpoint(path: "/v1/playbooks/\(playbookId)/weekly-cycles", method: .get)
    }
}
