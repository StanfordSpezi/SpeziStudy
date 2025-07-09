//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import Spezi
import SpeziStudy
import SwiftUI


final class TestAppDelegate: SpeziAppDelegate {
    override var configuration: Configuration {
        Configuration(standard: TestAppStandard()) {
            StudyManager(
                preferredLocale: Locale(identifier: "en_US"),
                persistence: .inMemory
            )
        }
    }
}
