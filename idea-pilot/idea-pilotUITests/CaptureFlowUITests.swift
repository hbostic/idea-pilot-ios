//
//  CaptureFlowUITests.swift
//  idea-pilotUITests
//
//  End-to-end test for the Quick Add (capture) flow.
//  Taps the capture button, selects a playbook,
//  enters a task title, and submits.
//

import XCTest

final class CaptureFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testQuickAddTask() throws {
        let app = UITestApp.launch()

        // Wait for main tab bar.
        let captureButton = app.buttons["tab_capture"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 5), "Capture button should appear")

        // Open Quick Add sheet.
        captureButton.tap()

        // Wait for the title field to appear.
        let titleField = app.textFields["quickadd_title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Quick Add title field should appear")

        // Select playbook from the picker menu.
        let playbookPicker = app.otherElements["quickadd_playbook_picker"]
        if playbookPicker.exists {
            playbookPicker.tap()
            // Tap the playbook option in the menu.
            let playbookOption = app.buttons["Side Project"]
            if playbookOption.waitForExistence(timeout: 2) {
                playbookOption.tap()
            }
        }

        // Enter a task title.
        titleField.tap()
        titleField.typeText("New test task")

        // Submit.
        let submitButton = app.buttons["quickadd_submit"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 2), "Submit button should appear")
        submitButton.tap()

        // After submission, the form should clear (title field empties)
        // and the sheet stays open for multi-capture.
        // Give the success flash time to clear.
        sleep(1)

        let titleValue = titleField.value as? String ?? ""
        XCTAssertTrue(
            titleValue.isEmpty || titleValue == "What needs to happen?",
            "Title field should be cleared after successful add"
        )
    }
}
