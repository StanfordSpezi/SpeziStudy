//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import class ModelsR4.Questionnaire
import SpeziFoundation
import SpeziHealthKit
import SpeziHealthKitBulkExport
@testable import SpeziStudyDefinition
import Testing


@Suite
struct StudyDefinitionTests {
    @Test
    func studyEncodingAndDecoding() throws {
        let data = try JSONEncoder().encode(Self.testStudyBundle)
        let decodedStudy = try JSONDecoder().decode(StudyDefinition.self, from: data, configuration: .init(allowTrivialSchemaMigrations: true))
        #expect(try decodedStudy == Self.testStudyBundle)
    }
    
    
    @Test
    func decodedStudyVersionExtraction() throws {
        let input1 = try JSONEncoder().encode(Self.testStudyBundle)
        #expect(try StudyDefinition.schemaVersion(of: input1, using: JSONDecoder()) == StudyDefinition.schemaVersion)
        
        let input2 = try #require(#"{"schemaVersion":"1.2.3", "glorb": "florb"}"#.data(using: .utf8))
        #expect(try StudyDefinition.schemaVersion(of: input2, using: JSONDecoder()) == Version(1, 2, 3))
    }
}


extension Locale.Language {
    static let english = Locale.Language(identifier: "en")
}


extension Questionnaire {
    static func named(_ name: String) throws -> Questionnaire {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            throw NSError(
                domain: "edu.stanford.spezi",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Failed to load data"]
            )
        }
        return try JSONDecoder().decode(Questionnaire.self, from: data)
    }
}


// MARK: Test Study

extension StudyDefinitionTests {
    static var testStudyBundle: StudyDefinition {
        get throws {
            try StudyBundleTests.testStudyBundle.studyDefinition
        }
    }
}
