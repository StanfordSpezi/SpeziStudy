//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziScheduler


extension StudyDefinition {
    /// A study's schedule.
    public struct Schedule: StudyDefinitionElement { // maybe just use an array instead?
        public var elements: [ScheduleElement]
        
        public init(elements: [ScheduleElement]) {
            self.elements = elements
        }
    }
    
    /// A schedule, defining when a ``Component`` should be activated.
    public enum ComponentSchedule: StudyDefinitionElement {
        /// The base, relative to which a relatiive point in time is defined
        public enum RelativePointInTimeBase: StudyDefinitionElement {
            /// When the participant enrolls in the study, or when the study begins
            case studyBegin
            /// when the participant leaves the study, when the study officially ends
            case studyEnd
            /// When a task created for the other, referenced component is marked as completed.
            case completion(of: StudyDefinition.Component.ID)
        }
        
        public enum RecurrenceRuleInput: StudyDefinitionElement {
            case daily(interval: Int = 1, hour: Int, minute: Int = 0)
            case weekly(interval: Int = 1, weekday: Locale.Weekday, hour: Int, minute: Int = 0)
        }
        
        // Temporarily disabled due to SwiftData issues
//        /// The schedule should run once, relative to the specified base
//        case once(RelativePointInTimeBase, offset: Swift.Duration = .seconds(0))
        
        /// The schedule should run multiple times
        case repeated(RecurrenceRuleInput, startOffsetInDays: Int)
    }
    
    public struct ScheduleElement: StudyDefinitionElement {
        /// The identifier of the component this schedule is referencing
        public var componentId: StudyDefinition.Component.ID
        /// The schedule itself
        public var componentSchedule: ComponentSchedule
        /// Defines when an `Event` scheduled based on this schedule is allowed to be marked as completed.
        public var completionPolicy: SpeziScheduler.AllowedCompletionPolicy
        
        /// Creates a new `ScheduleElement`.
        public init(
            componentId: StudyDefinition.Component.ID,
            componentSchedule: ComponentSchedule,
            completionPolicy: SpeziScheduler.AllowedCompletionPolicy
        ) {
            self.componentId = componentId
            self.componentSchedule = componentSchedule
            self.completionPolicy = completionPolicy
        }
    }
}
