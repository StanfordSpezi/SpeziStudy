//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//


import Foundation
import SpeziStudyDefinition
import SwiftData


/// Models a user's participation in a study.
@Model
public final class StudyParticipationContext {
    /// The primary key.
    @Attribute(.unique)
    public private(set) var id = UUID()
    
    /// The date when the participant enrolled into the study.
    ///
    /// This date is used as the reference for any relative date operations (e.g.: scheduling tasks relative to the start of someome's participation in a study).
    public private(set) var enrollmentDate = Date()
    
    /// The study.
    public private(set) var study: StudyDefinition
    
    /// All questionnaire responses that were created as part of this study participation.
    @Relationship(deleteRule: .cascade, inverse: \SPCQuestionnaireEntry.SPC)
    public internal(set) var answeredQuestionnaires: [SPCQuestionnaireEntry] = []
    
    
    init(study: StudyDefinition) {
        self.study = study
    }
}
