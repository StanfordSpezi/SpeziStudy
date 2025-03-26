//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


/// Something that can appear in a `StudyDefinition`
public typealias StudyDefinitionElement = Hashable & Codable & Sendable


/// Defines a Study, as a composition of metadata, components, and a schedule.
public struct StudyDefinition: Identifiable, StudyDefinitionElement {
    public var metadata: Metadata
    public var components: [Component]
    public var schedule: Schedule
    
    public var id: UUID { metadata.id }
    
    public init(metadata: Metadata, components: [Component], schedule: Schedule) {
        self.metadata = metadata
        self.components = components
        self.schedule = schedule
    }
}


// MARK: Accessing stuff in a study, etc

extension StudyDefinition {
    /// The combined, effective HealthKit data collection of the entire study.
    public var allCollectedHealthData: HealthSampleTypesCollection {
        healthDataCollectionComponents.reduce(into: HealthSampleTypesCollection()) { acc, component in
            acc.merge(with: component.sampleTypes)
        }
    }
    
    /// All ``HealthDataCollectionComponent``s
    public var healthDataCollectionComponents: [HealthDataCollectionComponent] {
        components.compactMap { component in
            switch component {
            case .healthDataCollection(let component):
                component
            case .informational, .questionnaire:
                nil
            }
        }
    }
    
    /// Returns the first component with the specified id
    public func component(withId id: Component.ID) -> Component? {
        components.first { $0.id == id }
    }
}


extension StudyDefinition.Component {
    /// The components display title
    public var displayTitle: String? { // TODO is this actually needed / smth we wanna define in here?
        switch self {
        case .informational(let component):
            component.title
        case .questionnaire(let component):
            component.questionnaire.title?.value?.string
        case .healthDataCollection:
            nil
        }
    }
}


extension Swift.Duration {
    /// The duration's total length, in milliseconds.
    public var totalMilliseconds: Double {
        Double(components.seconds) * 1000 + Double(components.attoseconds) * 1e-15
    }
    
    /// The duration's total length, in seconds.
    public var totalSeconds: Double {
        totalMilliseconds / 1000
    }
}
