//
//  AppConfiguration.swift
//  idea-pilot
//
//  Centralized app configuration with compile-time API URL switching.
//

import Foundation

/// Centralized configuration for the Idea Pilot app.
///
/// Provides build-configuration-based values such as the API base URL,
/// app version, and build number. Debug builds point to localhost;
/// Release builds point to the production API.
///
/// Usage:
/// ```swift
/// let client = APIClient(baseURL: AppConfiguration.apiBaseURL)
/// let version = AppConfiguration.appVersion
/// ```
nonisolated enum AppConfiguration {

    /// The base URL for all API requests.
    ///
    /// - Debug: `http://localhost:5003` (local development server)
    /// - Release: `https://api.ideapilot.app` (production)
    static let apiBaseURL: URL = {
        #if DEBUG
        URL(string: "http://localhost:5003")!
        #else
        URL(string: "https://api.ideapilot.app")!
        #endif
    }()

    /// The app version string from the main bundle (e.g., `"1.0.0"`).
    ///
    /// Returns `"0.0.0"` if the key is missing (should not happen in production).
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    /// The build number string from the main bundle (e.g., `"42"`).
    ///
    /// Returns `"0"` if the key is missing.
    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    /// A formatted version string suitable for display (e.g., `"1.0.0 (42)"`).
    static var versionDisplay: String {
        "\(appVersion) (\(buildNumber))"
    }

    /// Whether the app is running in a Debug build configuration.
    static let isDebug: Bool = {
        #if DEBUG
        true
        #else
        false
        #endif
    }()
}
