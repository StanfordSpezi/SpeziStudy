//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


extension StudyDefinition {
    struct ValidationResult {
        var warnings = Set<ValidationWarning>()
        var issues = Set<ValidationIssue>()
    }
    
    enum ValidationWarning: Hashable, /*CustomStringConvertible,*/ Sendable {
        /// The component does not have any schedules associated with it
        case componentNotScheduled(Component)
    }
    
    enum ValidationIssue: Hashable, /*CustomStringConvertible,*/ Sendable {
        /// The study definition contains multiple components with the same id
        case conflictingComponents(id: UUID, [Component])
        /// The study definition contains multiple schedules with the same id
        case conflictingSchedules(id: UUID, [ComponentSchedule])
        /// The schedule is referencing a component that does not exist.
        case scheduleReferencingUnknownComponent(ComponentSchedule)
    }
    
    
    /// Performs a simple validation of the study definition's integrity, checking e.g. that there are no references to non-existing componts.
    public func validate(in studyBundle: StudyBundle) -> Bool {
        validate(in: studyBundle).issues.isEmpty
    }
    
    
    func validate(in studyBundle: StudyBundle) -> ValidationResult {
        var result = ValidationResult()
        do { // check components
            let componentsById = components.grouped(by: \.id)
            for (id, components) in componentsById where components.count > 1 {
                result.issues.insert(.conflictingComponents(id: id, components))
            }
        }
        do { // check schedules
            let schedulesById = componentSchedules.grouped(by: \.id)
            for (id, schedules) in schedulesById where schedules.count > 1 {
                result.issues.insert(.conflictingSchedules(id: id, schedules))
            }
        }
        for component in components {
            if componentSchedules.count(where: { $0.componentId == component.id }) == 0, component.kind != .internal {
                result.warnings.insert(.componentNotScheduled(component))
            }
//            switch component {
//            case .informational(let component):
//            }
            // TODO check that the file refs can resolve! (in at least 1 language (=EN))
        }
        for schedule in componentSchedules {
            if self.component(withId: schedule.componentId) == nil {
                result.issues.insert(.scheduleReferencingUnknownComponent(schedule))
            }
        }
        return result
    }
}
