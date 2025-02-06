//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@testable import SpeziStudy
import XCTest


final class SpeziStudyTests: XCTestCase {
    func testSpeziStudy() throws {
        let templatePackage = TemplatePackage()
        XCTAssertEqual(templatePackage.stanford, "Stanford University")
    }
}
