//
//  idea_pilotUITests.swift
//  idea-pilotUITests
//
//  Created by Harold Bostic on 2/21/26.
//

import XCTest

final class idea_pilotUITests: XCTestCase {

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
