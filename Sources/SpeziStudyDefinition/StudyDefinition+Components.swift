//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
@preconcurrency import class ModelsR4.Questionnaire


// MARK: Definitions

extension StudyDefinition {
    public enum Component: Identifiable, StudyDefinitionElement {
        case informational(InformationalComponent)
        case questionnaire(QuestionnaireComponent)
        case healthDataCollection(HealthDataCollectionComponent)
        
        public var id: UUID {
            switch self {
            case .informational(let component):
                component.id
            case .healthDataCollection(let component):
                component.id
            case .questionnaire(let component):
                component.id
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
        public var id: UUID
        public var title: String
        public var headerImage: String // TODO find smth better here!!!
        public var body: String
        
        public init(id: UUID, title: String, headerImage: String, body: String) {
            self.id = id
            self.title = title
            self.headerImage = headerImage
            self.body = body
        }
    }
    
    
    public struct HealthDataCollectionComponent: Identifiable, StudyDefinitionElement {
        public var id: UUID
        public var sampleTypes: HealthSampleTypesCollection
        
        public init(id: UUID, sampleTypes: HealthSampleTypesCollection) {
            self.id = id
            self.sampleTypes = sampleTypes
        }
    }
    
    
    public struct QuestionnaireComponent: Identifiable, StudyDefinitionElement {
        /// - parameter id: the id of this study component, **not** of the questionnaire
        public let id: UUID
        public let questionnaire: Questionnaire
        
        public init(id: UUID, questionnaire: Questionnaire) {
            self.id = id
            self.questionnaire = questionnaire
        }
    }
}


// MARK: Mutating

extension StudyDefinition {
    public mutating func removeComponent(at idx: Int) {
        let component = components.remove(at: idx)
        schedule.elements.removeAll { $0.componentId == component.id }
    }
}
