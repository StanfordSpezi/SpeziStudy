//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


extension StudyDefinition {
    /// Study Component which prompts the participant to read an informational article
    public struct InformationalComponent: Identifiable, StudyDefinitionElement {
        public var id: UUID
        public var bodyFileRef: StudyBundle.FileReference
        
        public init(id: UUID, bodyFileRef: StudyBundle.FileReference) {
            precondition(bodyFileRef.category == .informationalArticle)
            self.id = id
            self.bodyFileRef = bodyFileRef
        }
    }
}
