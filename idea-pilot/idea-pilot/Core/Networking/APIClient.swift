//
//  APIClient.swift
//  idea-pilot
//
//  Centralized networking layer for all API communication.
//

import Foundation

/// The centralized networking layer for all Idea Pilot API calls.
///
/// All requests flow through `APIClient`, which handles:
/// - Typed JSON encoding/decoding
/// - Bearer token injection via `TokenProviding`
/// - Transparent 401 refresh-and-retry (once)
/// - Error mapping to `APIError`
/// - Debug-only request/response logging
///
/// Usage:
/// ```swift
/// let client = APIClient(baseURL: url, session: .shared, tokenProvider: tokenManager)
/// let playbooks: [PlaybookDTO] = try await client.request(.getPlaybooks())
/// ```
final class APIClient: Sendable {

    private let baseURL: URL
    private let session: URLSession
    private let tokenProvider: (any TokenProviding)?
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    /// Creates an API client.
    ///
    /// - Parameters:
    ///   - baseURL: The root URL of the API (e.g., `https://api.ideapilot.app`).
    ///   - session: The `URLSession` to use. Injectable for testing.
    ///   - tokenProvider: Provides access tokens and refresh capability. Pass `nil` for unauthenticated clients.
    init(baseURL: URL, session: URLSession = .shared, tokenProvider: (any TokenProviding)? = nil) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    /// Sends a request and decodes the response into the given type.
    ///
    /// - Parameter endpoint: The API endpoint to call.
    /// - Returns: The decoded response.
    /// - Throws: `APIError` on failure.
    func request<T: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> T {
        let urlRequest = try await buildURLRequest(for: endpoint)
        return try await execute(request: urlRequest, endpoint: endpoint, isRetry: false)
    }

    /// Sends a request that returns no response body (e.g., DELETE, 204).
    ///
    /// - Parameter endpoint: The API endpoint to call.
    /// - Throws: `APIError` on failure.
    func requestVoid(_ endpoint: Endpoint) async throws {
        let urlRequest = try await buildURLRequest(for: endpoint)
        let (data, response) = try await performRequest(urlRequest)
        let statusCode = response.statusCode

        if statusCode == 401 && endpoint.requiresAuth {
            try await handleUnauthorized(endpoint: endpoint)
            return
        }

        try mapErrorStatus(statusCode, data: data)
    }

    // MARK: - Mutation Replay

    /// Replays a queued mutation with pre-encoded body data.
    ///
    /// Used by `SyncEngine` to drain the mutation queue. Body data was
    /// pre-encoded at enqueue time (snake_case + ISO8601) so it is injected
    /// directly without re-encoding.
    ///
    /// Includes full auth handling (token injection + 401 refresh-and-retry).
    ///
    /// - Parameters:
    ///   - path: The endpoint path (e.g., `"/v1/tasks"`).
    ///   - method: The HTTP method.
    ///   - bodyData: Pre-encoded JSON body data, or `nil`.
    ///   - requiresAuth: Whether to inject the Bearer token.
    /// - Returns: The raw response `Data`.
    /// - Throws: `APIError` on failure.
    func replayMutation(
        path: String,
        method: HTTPMethod,
        bodyData: Data?,
        requiresAuth: Bool = true
    ) async throws -> Data {
        let endpoint = Endpoint(path: path, method: method, requiresAuth: requiresAuth)
        var request = try await buildURLRequest(for: endpoint)

        // Override body with pre-encoded data (already snake_case + ISO8601).
        if let bodyData {
            request.httpBody = bodyData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await performRequest(request)

        #if DEBUG
        logRequest(request, statusCode: response.statusCode, data: data)
        #endif

        // Handle 401 with token refresh and retry.
        if response.statusCode == 401 && requiresAuth {
            guard let provider = tokenProvider else {
                throw APIError.sessionExpired
            }
            do {
                try await provider.refresh()
            } catch {
                await provider.clearTokens()
                throw APIError.sessionExpired
            }
            var retryRequest = try await buildURLRequest(for: endpoint)
            if let bodyData {
                retryRequest.httpBody = bodyData
                retryRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            let (retryData, retryResponse) = try await performRequest(retryRequest)

            #if DEBUG
            logRequest(retryRequest, statusCode: retryResponse.statusCode, data: retryData)
            #endif

            try mapErrorStatus(retryResponse.statusCode, data: retryData)
            return retryData
        }

        try mapErrorStatus(response.statusCode, data: data)
        return data
    }

    // MARK: - Private

    private func buildURLRequest(for endpoint: Endpoint) async throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: true)
        components?.queryItems = endpoint.queryItems

        guard let url = components?.url else {
            throw APIError.badRequest("Invalid URL for path: \(endpoint.path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body = endpoint.body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        if endpoint.requiresAuth, let token = await tokenProvider?.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private func execute<T: Decodable & Sendable>(
        request: URLRequest,
        endpoint: Endpoint,
        isRetry: Bool
    ) async throws -> T {
        let (data, response) = try await performRequest(request)
        let statusCode = response.statusCode

        #if DEBUG
        logRequest(request, statusCode: statusCode, data: data)
        #endif

        if statusCode == 401 && !isRetry && endpoint.requiresAuth {
            return try await handleUnauthorized(endpoint: endpoint)
        }

        try mapErrorStatus(statusCode, data: data)

        do {
            return try decoder.decode(T.self, from: data)
        } catch let error as DecodingError {
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    private func handleUnauthorized<T: Decodable & Sendable>(endpoint: Endpoint) async throws -> T {
        guard let provider = tokenProvider else {
            throw APIError.sessionExpired
        }

        do {
            try await provider.refresh()
        } catch {
            await provider.clearTokens()
            throw APIError.sessionExpired
        }

        let retryRequest = try await buildURLRequest(for: endpoint)
        return try await execute(request: retryRequest, endpoint: endpoint, isRetry: true)
    }

    private func handleUnauthorized(endpoint: Endpoint) async throws {
        guard let provider = tokenProvider else {
            throw APIError.sessionExpired
        }

        do {
            try await provider.refresh()
        } catch {
            await provider.clearTokens()
            throw APIError.sessionExpired
        }

        let retryRequest = try await buildURLRequest(for: endpoint)
        let (data, response) = try await performRequest(retryRequest)
        try mapErrorStatus(response.statusCode, data: data)
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            if urlError.code == .notConnectedToInternet {
                throw APIError.offline
            }
            throw APIError.networkError(urlError)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        return (data, httpResponse)
    }

    private func mapErrorStatus(_ statusCode: Int, data: Data) throws {
        switch statusCode {
        case 200...299:
            return
        case 400, 409:
            let message = extractErrorMessage(from: data)
            throw APIError.badRequest(message)
        case 401:
            throw APIError.sessionExpired
        case 404:
            throw APIError.notFound
        case 500...599:
            let message = extractErrorMessage(from: data)
            throw APIError.serverError(statusCode, message)
        default:
            let message = extractErrorMessage(from: data)
            throw APIError.serverError(statusCode, message)
        }
    }

    private func extractErrorMessage(from data: Data) -> String? {
        // Try flat format: {"message": "..."}
        struct FlatErrorBody: Decodable { let message: String? }
        if let message = try? JSONDecoder().decode(FlatErrorBody.self, from: data).message {
            return message
        }
        // Try nested format: {"error": {"message": "..."}}
        struct NestedErrorBody: Decodable {
            let error: FlatErrorBody
        }
        return try? JSONDecoder().decode(NestedErrorBody.self, from: data).error.message
    }

    #if DEBUG
    private func logRequest(_ request: URLRequest, statusCode: Int, data: Data) {
        let method = request.httpMethod ?? "?"
        let url = request.url?.absoluteString ?? "?"
        let bodyPreview = data.prefix(500)
        let bodyString = String(data: bodyPreview, encoding: .utf8) ?? "<binary>"
        print("[\(method)] \(url) → \(statusCode) (\(data.count) bytes)")
        if data.count > 0 {
            print("  Response: \(bodyString)")
        }
    }
    #endif
}
