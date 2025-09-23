//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


extension StudyDefinition {
    /// Study Component which prompts the user to perform an ECG, e.g. using their Apple Watch.
    public struct ECGComponent: Identifiable, StudyDefinitionElement {
        public var id: UUID
        
        public init(id: UUID) {
            self.id = id
        }
    }
}
