//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import XCTest
import XCTestExtensions
import XCTHealthKit


class TestAppUITests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }
    

    @MainActor
    func testStudyEnrollment() throws {
        let app = XCUIApplication()
        app.launch()
        
        app.buttons["Enroll in TestStudy (v1)"].tap()
        if app.navigationBars["Health Access"].waitForExistence(timeout: 5) {
            try app.handleHealthKitAuthorization()
        }
        
        XCTAssertTrue(app.staticTexts["TestStudy"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.staticTexts["Study ID, 885099E4-6318-43CC-BFF1-7D7FAD1968F6"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.staticTexts["Study Revision, 1"].waitForExistence(timeout: 1))
        let enrollmentDateText = DateFormatter.localizedString(from: .now, dateStyle: .short, timeStyle: .none)
        XCTAssertTrue(app.staticTexts["Enrollment Date, \(enrollmentDateText)"].waitForExistence(timeout: 1))
        
        XCTAssertTrue(app.staticTexts["Article1 Title"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.staticTexts["Social Support"].waitForExistence(timeout: 1))
        
        XCTAssertTrue(app.buttons["Complete Informational"].waitForExistence(timeout: 1))
        app.buttons["Complete Informational"].tap()
        XCTAssertTrue(app.buttons["Complete Informational"].waitForNonExistence(timeout: 1))
        
        // update the study to a newer version.
        // going from 1 to 2 will remove the questionnaire component.
        // since the informational component remains, and has already been completed, we expect it to stay completed.
        app.buttons["Update enrollment to study revision 2"].tap()
        XCTAssertTrue(app.staticTexts["Study Revision, 2"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.buttons["Complete Informational"].waitForNonExistence(timeout: 1))
        XCTAssertTrue(app.staticTexts["Social Support"].waitForNonExistence(timeout: 1))
        
        // update the study to a newer version.
        // going from 2 to 3 will introduce a new, second informative article component.
        // we expect this to show up, and we still expect the first article to stay completed.
        app.buttons["Update enrollment to study revision 3"].tap()
        XCTAssertTrue(app.staticTexts["Study Revision, 3"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.staticTexts["Article2 Title"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.staticTexts["Article1 Title, Completed"].waitForExistence(timeout: 1))
        
        // unenroll and make sure that everything gets removed
        app.buttons["Unenroll from Study"].tap()
        XCTAssertTrue(app.staticTexts["No Events"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["TestStudy"].exists)
        XCTAssertFalse(app.staticTexts["Study ID"].exists)
        XCTAssertFalse(app.staticTexts["Study Revision"].exists)
        XCTAssertFalse(app.staticTexts["Enrollment Date"].exists)
    }
}
