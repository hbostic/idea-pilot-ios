//
//  WeeklyPlanFlowUITests.swift
//  idea-pilotUITests
//
//  End-to-end test for the 3-step weekly planning flow.
//  Navigates to a playbook, opens the weekly plan,
//  and steps through Review → Select → Confirm.
//

import XCTest

final class WeeklyPlanFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testWeeklyPlanFullFlow() throws {
        let app = UITestApp.launch()

        // Navigate to Playbooks → Side Project.
        let playbooksTab = app.buttons["tab_playbooks"]
        XCTAssertTrue(playbooksTab.waitForExistence(timeout: 5))
        playbooksTab.tap()

        let playbookRow = app.buttons["playbook_row_pb-uitest"]
        XCTAssertTrue(playbookRow.waitForExistence(timeout: 5))
        playbookRow.tap()

        // Wait for PlaybookHomeView to load.
        let nowLane = app.buttons["lane_now"]
        XCTAssertTrue(nowLane.waitForExistence(timeout: 5))

        // Open the overflow menu and tap "Weekly Plan".
        let menuButton = app.buttons["playbook_menu"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 3), "Overflow menu should exist")
        menuButton.tap()

        let weeklyPlanOption = app.buttons["Weekly Plan"]
        XCTAssertTrue(weeklyPlanOption.waitForExistence(timeout: 3), "Weekly Plan menu option should appear")
        weeklyPlanOption.tap()

        // Step 1: Review — tap Continue.
        let continueButton = app.buttons["weekly_continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5), "Continue button should appear on review step")
        continueButton.tap()

        // Step 2: Select — pick a task and tap "Plan Week".
        let planWeekButton = app.buttons["weekly_plan_week"]
        XCTAssertTrue(planWeekButton.waitForExistence(timeout: 5), "Plan Week button should appear on select step")

        // Select a task if checkboxes are available.
        let taskCheckbox = app.buttons["weekly_task_t-now-1"]
        if taskCheckbox.waitForExistence(timeout: 3) {
            taskCheckbox.tap()
        }

        planWeekButton.tap()

        // Step 3: Confirm — tap "Let's Go".
        let letsGoButton = app.buttons["weekly_lets_go"]
        XCTAssertTrue(letsGoButton.waitForExistence(timeout: 5), "Let's Go button should appear on confirm step")
        letsGoButton.tap()

        // After dismissing the weekly plan flow, we should be back
        // at PlaybookHomeView with lane segments visible.
        XCTAssertTrue(nowLane.waitForExistence(timeout: 5), "Should return to PlaybookHome after weekly plan flow")
    }
}
