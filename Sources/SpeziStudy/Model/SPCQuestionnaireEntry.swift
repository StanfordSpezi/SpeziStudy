//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
// NOTE: we need to import it like this, since if we were to import the whole of ModelsR4, we'd have a name collision
// between the `Observation` type defines in ModelsR4, and Apple's `Observation` framework, and the @Model macro expansion would fail to compile...
import class ModelsR4.QuestionnaireResponse
import SwiftData


/// An answered questionnaire
@Model
public class SPCQuestionnaireEntry {
    /// Identifier uniquely identifying this entry.
    ///
    /// This also acts as a primary key.
    @Attribute(.unique)
    public private(set) var id = UUID()
    
    /// The ``StudyParticipationContext`` to which this entry belongs.
    public private(set) var SPC: StudyParticipationContext
    
    /// The FHIR-QuestionnaireResponse-encoded response
    @Attribute(.transformable(by: JSONEncodingValueTransformer<QuestionnaireResponse>.self))
    public internal(set) var response: QuestionnaireResponse
    
    /// Creates a new instance
    init(SPC: StudyParticipationContext, response: QuestionnaireResponse) {
        self.SPC = SPC
        self.response = response
    }
}
