//
//  TokenManager.swift
//  idea-pilot
//
//  Manages JWT token storage, retrieval, and refresh.
//  Stores tokens in the iOS Keychain via `KeychainStorable`.
//

import Foundation

// MARK: - TokenManagerError

/// Errors specific to `TokenManager` operations.
nonisolated enum TokenManagerError: Error, Sendable {
    /// No refresh token is stored; the user must sign in again.
    case noRefreshToken
    /// The refresh network request failed.
    case refreshFailed(underlying: (any Error)?)
}

// MARK: - TokenManager

/// Manages authentication tokens with Keychain persistence and in-memory caching.
///
/// `TokenManager` is an `actor` that provides thread-safe access to JWT tokens.
/// It conforms to `TokenProviding` so `APIClient` can use it for Bearer token
/// injection and transparent 401 refresh-and-retry.
///
/// **Storage**: Tokens are persisted as separate Keychain items under the service
/// name `com.lifeautomation.idea-pilot` with `kSecAttrAccessibleAfterFirstUnlock`
/// for background sync compatibility.
///
/// **Caching**: Keychain values are cached in-memory on the actor to avoid
/// repeated IPC calls to `securityd`. The cache is populated lazily on first
/// read or eagerly when `storeSession(_:)` is called.
///
/// **Refresh**: The actor calls the refresh endpoint directly via `URLSession`
/// (not through `APIClient`) to avoid a circular dependency.
///
/// Usage:
/// ```swift
/// let tokenManager = TokenManager(keychain: KeychainService(), baseURL: apiURL)
/// let client = APIClient(baseURL: apiURL, tokenProvider: tokenManager)
/// ```
nonisolated actor TokenManager: TokenProviding {

    // MARK: - Keychain Keys

    private enum Keys {
        static let accessToken = "com.lifeautomation.idea-pilot.accessToken"
        static let refreshToken = "com.lifeautomation.idea-pilot.refreshToken"
        static let userId = "com.lifeautomation.idea-pilot.userId"
        static let email = "com.lifeautomation.idea-pilot.email"
    }

    // MARK: - Dependencies

    private let keychain: any KeychainStorable
    private let baseURL: URL
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // MARK: - In-Memory Cache

    private var _accessToken: String?
    private var _refreshToken: String?
    private var _userId: String?
    private var _email: String?
    private var cacheLoaded = false

    // MARK: - Init

    /// Creates a TokenManager.
    ///
    /// - Parameters:
    ///   - keychain: The Keychain storage backend. Injectable for testing.
    ///   - baseURL: The API base URL for the refresh endpoint.
    ///   - session: The `URLSession` for refresh requests. Injectable for testing.
    init(
        keychain: any KeychainStorable = KeychainService(),
        baseURL: URL,
        session: URLSession = .shared
    ) {
        self.keychain = keychain
        self.baseURL = baseURL
        self.session = session

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    // MARK: - TokenProviding Conformance

    /// The current access token, or `nil` if the user is not authenticated.
    var accessToken: String? {
        loadCacheIfNeeded()
        return _accessToken
    }

    /// Attempts to refresh the access token using the stored refresh token.
    ///
    /// Calls `POST /v1/auth/refresh` directly via `URLSession` (not `APIClient`)
    /// to avoid a circular dependency. On success, updates both Keychain and cache.
    func refresh() async throws {
        loadCacheIfNeeded()

        guard let refreshToken = _refreshToken else {
            throw TokenManagerError.noRefreshToken
        }

        let dto = RefreshTokenRequestDTO(refreshToken: refreshToken)
        let body = try encoder.encode(dto)

        let url = baseURL.appendingPathComponent("/v1/auth/refresh")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw TokenManagerError.refreshFailed(underlying: error)
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw TokenManagerError.refreshFailed(underlying: nil)
        }

        let tokens: AuthTokensDTO
        do {
            tokens = try decoder.decode(AuthTokensDTO.self, from: data)
        } catch {
            throw TokenManagerError.refreshFailed(underlying: error)
        }

        try storeSession(tokens.toUserSession())
    }

    /// Clears all stored tokens from both Keychain and in-memory cache.
    ///
    /// Called on explicit sign-out or when a refresh attempt fails.
    /// Keychain delete errors are logged but do not throw — best-effort cleanup.
    func clearTokens() {
        _accessToken = nil
        _refreshToken = nil
        _userId = nil
        _email = nil
        cacheLoaded = true

        for key in [Keys.accessToken, Keys.refreshToken, Keys.userId, Keys.email] {
            do {
                try keychain.delete(forKey: key)
            } catch {
                #if DEBUG
                print("[TokenManager] Warning: Failed to delete Keychain item '\(key)': \(error)")
                #endif
            }
        }
    }

    // MARK: - Public API (beyond TokenProviding)

    /// Whether the user has a stored access token.
    var isAuthenticated: Bool {
        loadCacheIfNeeded()
        return _accessToken != nil
    }

    /// The stored user ID, or `nil` if not authenticated.
    var userId: String? {
        loadCacheIfNeeded()
        return _userId
    }

    /// The stored email, or `nil` if not authenticated.
    var email: String? {
        loadCacheIfNeeded()
        return _email
    }

    /// The current user session reconstructed from cached values, or `nil` if not authenticated.
    var currentSession: UserSession? {
        loadCacheIfNeeded()
        guard let accessToken = _accessToken,
              let refreshToken = _refreshToken,
              let userId = _userId,
              let email = _email else {
            return nil
        }
        return UserSession(
            userId: userId,
            email: email,
            accessToken: accessToken,
            refreshToken: refreshToken
        )
    }

    /// Stores a complete user session in both Keychain and cache.
    ///
    /// Called after successful login or token refresh.
    ///
    /// - Parameter session: The user session to persist.
    /// - Throws: `KeychainError` if any Keychain write fails.
    func storeSession(_ session: UserSession) throws {
        try keychain.save(session.accessToken, forKey: Keys.accessToken)
        try keychain.save(session.refreshToken, forKey: Keys.refreshToken)
        try keychain.save(session.userId, forKey: Keys.userId)
        try keychain.save(session.email, forKey: Keys.email)

        _accessToken = session.accessToken
        _refreshToken = session.refreshToken
        _userId = session.userId
        _email = session.email
        cacheLoaded = true
    }

    // MARK: - Private

    /// Loads all Keychain values into the in-memory cache once.
    ///
    /// Read failures return `nil` for that field (graceful degradation).
    private func loadCacheIfNeeded() {
        guard !cacheLoaded else { return }
        cacheLoaded = true

        _accessToken = try? keychain.load(forKey: Keys.accessToken)
        _refreshToken = try? keychain.load(forKey: Keys.refreshToken)
        _userId = try? keychain.load(forKey: Keys.userId)
        _email = try? keychain.load(forKey: Keys.email)
    }
}
