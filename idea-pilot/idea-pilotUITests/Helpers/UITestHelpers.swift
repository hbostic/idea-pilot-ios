//
//  UITestHelpers.swift
//  idea-pilotUITests
//
//  Shared helpers for launching the app in UI test mode
//  with deterministic mock services.
//

import XCTest

enum UITestApp {

    /// Launches the app in UI test mode with mock services injected.
    ///
    /// - Parameter signedOut: When `true`, launches without pre-loaded
    ///   auth tokens so the app shows the sign-in screen.
    /// - Returns: The launched `XCUIApplication` instance.
    @MainActor
    static func launch(signedOut: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TEST_MODE"]
        if signedOut {
            app.launchArguments.append("UI_TEST_SIGNED_OUT")
        }
        app.launch()
        return app
    }
}
