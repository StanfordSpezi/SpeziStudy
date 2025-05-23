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
        let data = try JSONEncoder().encode(testStudy)
        let decodedStudy = try JSONDecoder().decode(StudyDefinition.self, from: data, configuration: .init(allowTrivialSchemaMigrations: true))
        #expect(try decodedStudy == testStudy)
    }
    
    
    @Test
    func decodedStudyVersionExtraction() throws {
        let input1 = try JSONEncoder().encode(testStudy)
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
    private var testStudy: StudyDefinition {
        get throws {
            // swiftlint:disable force_unwrapping
            let studyId = UUID(uuidString: "1E82CA84-E031-43C1-9CA4-9F68B5F246B8")!
            let article1ComponentId = UUID(uuidString: "F924B17E-F45C-40D8-8B8A-C694C6D4956D")!
            let article2ComponentId = UUID(uuidString: "6BE663DB-912F-4F4E-BD62-D743A9FB8941")!
            let questionnaireComponentId = UUID(uuidString: "7E3CD36F-26CD-418B-9CAD-CFB268070162")!
            let healthDataCollectionComponentId = UUID(uuidString: "A52CBB75-6F9D-4B59-BA86-01532EFE41D2")!
            let schedule1Id = UUID(uuidString: "92E77E46-4135-41B4-BE23-59AD233C4C79")!
            let schedule2Id = UUID(uuidString: "D7263B0D-29BB-42BB-BF92-FE4DBC170281")!
            let schedule3Id = UUID(uuidString: "B73A310D-692A-4C9F-9FA5-897FDAEAC796")!
            // swiftlint:enable force_unwrapping
            return StudyDefinition(
                studyRevision: 0,
                metadata: StudyDefinition.Metadata(
                    id: studyId,
                    title: "Test Study",
                    explanationText: "This is our TestStudy",
                    shortExplanationText: "This is our TestStudy",
                    participationCriterion: .ageAtLeast(18) && !.ageAtLeast(60) && (.isFromRegion(.unitedStates) || .isFromRegion(.unitedKingdom)) && .speaksLanguage(.english),
                    // swiftlint:disable:previous line_length
                    enrollmentConditions: .requiresInvitation(verificationEndpoint: try #require(URL(string: "https://mhc.stanford.edu/api/enroll")))
                ),
                components: [
                    .informational(.init(
                        id: article1ComponentId,
                        title: "Informational Component #1",
                        headerImage: "Header1",
                        body: "This is the text of the first informational component"
                    )),
                    .informational(.init(
                        id: article2ComponentId,
                        title: "Informational Component #2",
                        headerImage: "Header2",
                        body: "This is the text of the second informational component"
                    )),
                    .questionnaire(.init(
                        id: questionnaireComponentId,
                        questionnaire: try .named("SocialSupportQuestionnaire")
                    )),
                    .healthDataCollection(.init(
                        id: healthDataCollectionComponentId,
                        sampleTypes: [SampleType.heartRate, SampleType.stepCount, SampleType.sleepAnalysis],
                        historicalDataCollection: .enabled(.last(DateComponents(year: 7, month: 6)))
                    ))
                ],
                componentSchedules: [
                    .init(
                        id: schedule1Id,
                        componentId: article1ComponentId,
                        scheduleDefinition: .repeated(.daily(hour: 11, minute: 21), offset: .days(4)),
                        completionPolicy: .afterStart,
                        notifications: .enabled(thread: .none)
                    ),
                    .init(
                        id: schedule2Id,
                        componentId: article2ComponentId,
                        scheduleDefinition: .repeated(.daily(interval: 2, hour: 17, minute: 41)),
                        completionPolicy: .anytime,
                        notifications: .enabled(thread: .global)
                    ),
                    .init(
                        id: schedule3Id,
                        componentId: questionnaireComponentId,
                        scheduleDefinition: .repeated(.weekly(weekday: .wednesday, hour: 21, minute: 59), offset: .days(1)),
                        completionPolicy: .sameDayAfterStart,
                        notifications: .enabled(thread: .task)
                    )
                ]
            )
        }
    }
}
