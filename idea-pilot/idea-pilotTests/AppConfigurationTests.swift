//
//  AppConfigurationTests.swift
//  idea-pilotTests
//
//  Unit tests for AppConfiguration.
//

import Foundation
import Testing
@testable import idea_pilot

@Suite("AppConfiguration")
struct AppConfigurationTests {

    @Test("apiBaseURL returns localhost in Debug builds")
    func apiBaseURLDebug() {
        // Tests run under the Debug configuration.
        #expect(AppConfiguration.apiBaseURL.absoluteString == "http://localhost:5003")
    }

    @Test("apiBaseURL is a valid URL")
    func apiBaseURLValid() {
        let url = AppConfiguration.apiBaseURL
        #expect(url.scheme == "http" || url.scheme == "https")
        #expect(url.host != nil)
    }

    @Test("isDebug is true in test builds")
    func isDebugTrue() {
        #expect(AppConfiguration.isDebug == true)
    }

    @Test("appVersion returns a non-empty string")
    func appVersionNonEmpty() {
        #expect(!AppConfiguration.appVersion.isEmpty)
    }

    @Test("buildNumber returns a non-empty string")
    func buildNumberNonEmpty() {
        #expect(!AppConfiguration.buildNumber.isEmpty)
    }

    @Test("versionDisplay combines version and build number")
    func versionDisplayFormat() {
        let display = AppConfiguration.versionDisplay
        #expect(display.contains("("))
        #expect(display.contains(")"))
        #expect(display.contains(AppConfiguration.appVersion))
        #expect(display.contains(AppConfiguration.buildNumber))
    }
}
