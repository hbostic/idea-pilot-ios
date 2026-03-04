//
//  AuthFlowUITests.swift
//  idea-pilotUITests
//
//  End-to-end test for the sign-in authentication flow.
//  Launches in signed-out mode, fills in credentials,
//  and verifies navigation to the main tab bar.
//

import XCTest

final class AuthFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSignInFlow() throws {
        let app = UITestApp.launch(signedOut: true)

        // Wait for auth screen to appear.
        let emailField = app.textFields["auth_email_field"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5), "Email field should appear")

        // Enter email.
        emailField.tap()
        emailField.typeText("test@example.com")

        // Enter password — SecureField by default.
        let passwordField = app.secureTextFields["auth_password_field"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 2), "Password field should appear")
        passwordField.tap()
        passwordField.typeText("password123")

        // Tap sign in.
        let submitButton = app.buttons["auth_submit_button"]
        XCTAssertTrue(submitButton.isEnabled, "Submit button should be enabled")
        submitButton.tap()

        // Verify we land on the main tab bar.
        let nowTab = app.buttons["tab_now"]
        XCTAssertTrue(nowTab.waitForExistence(timeout: 5), "Now tab should appear after sign in")
    }

    @MainActor
    func testModeToggleToSignUp() throws {
        let app = UITestApp.launch(signedOut: true)

        let emailField = app.textFields["auth_email_field"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))

        // Toggle to sign-up mode.
        let modeToggle = app.buttons["auth_mode_toggle"]
        XCTAssertTrue(modeToggle.exists, "Mode toggle should exist")
        modeToggle.tap()

        // Confirm password field should now appear.
        let confirmField = app.secureTextFields["auth_confirm_password_field"]
        XCTAssertTrue(confirmField.waitForExistence(timeout: 2), "Confirm password field should appear in sign-up mode")
    }
}
