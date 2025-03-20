//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
@preconcurrency import class ModelsR4.Questionnaire


extension StudyDefinition {
    public enum Component: Identifiable, StudyDefinitionElement {
        case informational(InformationalComponent)
        /// - parameter id: the id of this study component, **not** of the questionnaire
        case questionnaire(id: UUID, questionnaire: Questionnaire)
        case healthDataCollection(HealthDataCollectionComponent)
        
        public var id: UUID {
            switch self {
            case .informational(let component):
                component.id
            case .healthDataCollection(let component):
                component.id
            case .questionnaire(let id, _):
                id
            }
        }
        
        /// Whether the component consists of something that we want the user to interact with
        ///
        /// TODO better name here. the idea is to differentiate between "internal" components (eg health data collection) that can run on their own,
        /// vc non-internal components that essentially just tell the user to do something.
        public var requiresUserInteraction: Bool {
            switch self {
            case .informational, .questionnaire:
                true
            case .healthDataCollection:
                false
            }
        }
    }
    
    
    public struct InformationalComponent: Identifiable, StudyDefinitionElement {
        public let id: UUID
        public let title: String
        public let headerImage: String // TODO find smth better here!!!
        public let body: String
        
        public init(id: UUID, title: String, headerImage: String, body: String) {
            self.id = id
            self.title = title
            self.headerImage = headerImage
            self.body = body
        }
    }
    
    
    public struct HealthDataCollectionComponent: Identifiable, StudyDefinitionElement {
        public let id: UUID
        public let sampleTypes: HealthSampleTypesCollection
        
        public init(id: UUID, sampleTypes: HealthSampleTypesCollection) {
            self.id = id
            self.sampleTypes = sampleTypes
        }
    }
}
