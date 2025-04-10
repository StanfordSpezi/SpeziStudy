//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import Spezi
import SpeziHealthKit
import SpeziScheduler
@_spi(TestingSupport)
@testable import SpeziStudy
import SpeziTesting
import Testing


private actor TestStandard: Standard, HealthKitConstraint {
    func handleNewSamples<Sample>(_ addedSamples: some Collection<Sample>, ofType sampleType: SampleType<Sample>) async {
        // ...
    }
    
    func handleDeletedObjects<Sample>(_ deletedObjects: some Collection<HKDeletedObject>, ofType sampleType: SampleType<Sample>) async {
        // ...
    }
}


@Suite("StudyManagerTests")
struct StudyManagerTests {
    private static let articleComponentId = UUID()
    
    private let testStudy = StudyDefinition(
        studyRevision: 0,
        metadata: .init(
            id: UUID(),
            title: "",
            explanationText: "",
            shortExplanationText: "",
            participationCriteria: .init(criterion: true),
            enrollmentConditions: .none
        ),
        components: [
            .informational(.init(id: Self.articleComponentId, title: "", headerImage: "", body: ""))
        ],
        componentSchedules: [
            .init(
                componentId: Self.articleComponentId,
                scheduleDefinition: .repeated(.daily(hour: 1, minute: 0), startOffsetInDays: 0),
                completionPolicy: .afterStart
            )
        ]
    )
    
    @Test
    @MainActor
    func testOrphanHandling() async throws {
        let allTime = Date.distantPast...Date.distantFuture
        let studyManager = StudyManager(persistence: .inMemory)
        withDependencyResolution(standard: TestStandard()) {
            studyManager
        }
        try await studyManager.enroll(in: testStudy)
        #expect(studyManager.studyEnrollments.count == 1)
        let enrollment = try #require(studyManager.studyEnrollments.first)
        #expect(enrollment.studyId == testStudy.id)
        #expect(enrollment.study == testStudy)
        #expect(try studyManager.scheduler.queryTasks(for: allTime).count == 1)
        studyManager.modelContext.delete(enrollment)
        #expect(try studyManager.scheduler.queryTasks(for: allTime).count == 1)
        try studyManager.removeOrphanedTasks()
        #expect(try studyManager.scheduler.queryTasks(for: allTime).isEmpty)
    }
}
