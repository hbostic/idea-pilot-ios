//
//  ExecutionFlowUITests.swift
//  idea-pilotUITests
//
//  End-to-end test for the task execution flow.
//  Navigates to a playbook, verifies tasks appear,
//  and completes a task via the checkbox.
//

import XCTest

final class ExecutionFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testNavigateToPlaybookAndViewTasks() throws {
        let app = UITestApp.launch()

        // Navigate to Playbooks tab.
        let playbooksTab = app.buttons["tab_playbooks"]
        XCTAssertTrue(playbooksTab.waitForExistence(timeout: 5), "Playbooks tab should appear")
        playbooksTab.tap()

        // Tap the "Side Project" playbook row.
        let playbookRow = app.buttons["playbook_row_pb-uitest"]
        XCTAssertTrue(playbookRow.waitForExistence(timeout: 5), "Side Project playbook should appear")
        playbookRow.tap()

        // Verify lane segments appear.
        let nowLane = app.buttons["lane_now"]
        XCTAssertTrue(nowLane.waitForExistence(timeout: 5), "Now lane segment should appear")

        // Verify the Now task card is visible.
        let taskCard = app.buttons["task_card_t-now-1"]
        XCTAssertTrue(taskCard.waitForExistence(timeout: 3), "Task card should appear in Now lane")
    }

    @MainActor
    func testCompleteTask() throws {
        let app = UITestApp.launch()

        // Navigate to Playbooks → Side Project.
        let playbooksTab = app.buttons["tab_playbooks"]
        XCTAssertTrue(playbooksTab.waitForExistence(timeout: 5))
        playbooksTab.tap()

        let playbookRow = app.buttons["playbook_row_pb-uitest"]
        XCTAssertTrue(playbookRow.waitForExistence(timeout: 5))
        playbookRow.tap()

        // Wait for tasks to load.
        let checkbox = app.buttons["task_checkbox_t-now-1"]
        XCTAssertTrue(checkbox.waitForExistence(timeout: 5), "Task checkbox should appear")

        // Tap the checkbox to complete the task.
        checkbox.tap()

        // The task should animate out. Wait a moment for the completion animation.
        sleep(2)

        // After completion, the task card should eventually disappear.
        let taskCard = app.buttons["task_card_t-now-1"]
        let disappeared = taskCard.waitForNonExistence(timeout: 5)
        XCTAssertTrue(disappeared, "Completed task should disappear from the lane")
    }

    @MainActor
    func testSwitchLanes() throws {
        let app = UITestApp.launch()

        // Navigate to Playbooks → Side Project.
        let playbooksTab = app.buttons["tab_playbooks"]
        XCTAssertTrue(playbooksTab.waitForExistence(timeout: 5))
        playbooksTab.tap()

        let playbookRow = app.buttons["playbook_row_pb-uitest"]
        XCTAssertTrue(playbookRow.waitForExistence(timeout: 5))
        playbookRow.tap()

        // Start on Now lane — verify Now task visible.
        let nowLane = app.buttons["lane_now"]
        XCTAssertTrue(nowLane.waitForExistence(timeout: 5))

        // Switch to Next lane.
        let nextLane = app.buttons["lane_next"]
        XCTAssertTrue(nextLane.exists, "Next lane segment should exist")
        nextLane.tap()

        // Verify Next lane tasks appear.
        let nextTask = app.buttons["task_card_t-next-1"]
        XCTAssertTrue(nextTask.waitForExistence(timeout: 3), "Next lane task should appear")
    }
}
