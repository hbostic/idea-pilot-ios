//
//  APIError.swift
//  idea-pilot
//
//  Error types for the API networking layer.
//

import Foundation

/// Errors emitted by `APIClient`.
///
/// These cover the full range of failure modes: auth, network, decoding,
/// and server-side errors. UI layers can switch on these to display
/// appropriate feedback (inline banners, toasts, redirects).
nonisolated enum APIError: Error, Equatable, Sendable {

    /// The server returned 401 and the token refresh also failed.
    case sessionExpired

    /// The server returned 400 with an optional validation message.
    case badRequest(String?)

    /// The server returned 404.
    case notFound

    /// The server returned an unexpected status code (e.g., 500).
    case serverError(Int, String?)

    /// A network-level failure (timeout, DNS, TLS, etc.).
    case networkError(URLError)

    /// The response body could not be decoded into the expected type.
    case decodingError(String)

    /// The device has no internet connection.
    case offline
}
