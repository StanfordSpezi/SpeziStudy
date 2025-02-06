//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SwiftUI
import SpeziStudy


@main
struct UITestsApp: App {
    var body: some Scene {
        WindowGroup {
            Text(TemplatePackage().stanford)
            Text(operatingSystem)
        }
    }
}
