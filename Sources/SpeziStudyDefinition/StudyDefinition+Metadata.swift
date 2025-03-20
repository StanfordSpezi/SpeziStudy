//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


extension StudyDefinition {
    public struct Metadata: Identifiable, StudyDefinitionElement {
        public enum Icon: StudyDefinitionElement {
            case systemSymbol(String)
            case custom(URL)
        }
        
        public let id: UUID
        // eg "My Heart Counts"
        public var title: String
        // eg "MHC"
        public var shortTitle: String?
        /// Icon that will be used for this study.
        public var icon: Icon?
        /// Text that is presented to the user when they eg browse a list of studies they can enroll in
        public var shortExplanationText: String
        /// Long-form explanation of and/or introduction to the study.
        /// Is presented to the user
        public var explanationText: String // rename introductionText? introductoryText? instructions?
        
        /// Other studies this study depends on.
        ///
        /// A participant can only enroll in this study, if they are already enrolled in the other study referenced via this property.
        public var studyDependency: StudyDefinition.ID?
        
        /// The criteria which need to be satisfied by a person wishing to participate in the study
        public var participationCriteria: ParticipationCriteria
        
        /// The condition by which it is determined whether someone who satisfies the ``participationCriteria`` is allowed to enroll into the study.
        public var enrollmentConditions: EnrollmentConditions
        
        public init(
            id: UUID,
            title: String,
            shortTitle: String? = nil,
            icon: Icon? = nil, // swiftlint:disable:this function_default_parameter_at_end
            shortExplanationText: String,
            explanationText: String,
            studyDependency: StudyDefinition.ID? = nil, // swiftlint:disable:this function_default_parameter_at_end
            participationCriteria: ParticipationCriteria,
            enrollmentConditions: EnrollmentConditions
        ) {
            self.id = id
            self.title = title
            self.shortTitle = shortTitle
            self.icon = icon
            self.shortExplanationText = shortExplanationText
            self.explanationText = explanationText
            self.studyDependency = studyDependency
            self.participationCriteria = participationCriteria
            self.enrollmentConditions = enrollmentConditions
        }
    }
}
