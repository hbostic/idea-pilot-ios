//
//  HTTPMethod.swift
//  idea-pilot
//
//  HTTP methods supported by the API client.
//

import Foundation

/// HTTP methods used by the Idea Pilot API.
nonisolated enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case put = "PUT"
    case delete = "DELETE"
}
