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


final class StudyManagerTests: Sendable {
    private static let articleComponentId = UUID()
    
    private let studyBundle: StudyBundle
    
    init() throws {
        let testStudy = StudyDefinition(
            studyRevision: 0,
            metadata: .init(
                id: UUID(),
                title: "",
                explanationText: "",
                shortExplanationText: "",
                participationCriterion: true,
                enrollmentConditions: .none
            ),
            components: [
                .informational(.init(
                    id: Self.articleComponentId,
                    bodyFileRef: .init(category: .informationalArticle, filename: "a1", fileExtension: "md")
                ))
            ],
            componentSchedules: [
                .init(
                    id: UUID(),
                    componentId: Self.articleComponentId,
                    scheduleDefinition: .repeated(.daily(hour: 1, minute: 0)),
                    completionPolicy: .afterStart,
                    notifications: .enabled(thread: .custom("Articles"))
                )
            ]
        )
        let tmpUrl = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString, conformingTo: .speziStudyBundle)
        studyBundle = try StudyBundle.writeToDisk(
            at: tmpUrl,
            definition: testStudy,
            files: [
                StudyBundle.FileInput(
                    fileRef: .init(category: .informationalArticle, filename: "a1", fileExtension: "md"),
                    localization: .init(locale: .current),
                    contents: ""
                )
            ]
        )
    }
    
    @Test
    func orphanTaskHandling() async throws {
        let allTime = Date.distantPast...Date.distantFuture
        let studyManager = StudyManager(persistence: .inMemory)
        await withDependencyResolution(standard: TestStandard()) {
            Scheduler(persistence: .inMemory)
            studyManager
        }
        try await studyManager.enroll(in: studyBundle)
        try await MainActor.run {
            #expect(studyManager.studyEnrollments.count == 1)
            let enrollment = try #require(studyManager.studyEnrollments.first)
            #expect(enrollment.studyId == studyBundle.id)
            #expect(enrollment.studyId == studyBundle.studyDefinition.id)
            #expect(try #require(enrollment.studyBundle).studyDefinition == studyBundle.studyDefinition)
            try #expect(studyManager.scheduler.queryTasks(for: allTime).count == 1)
            studyManager.modelContext.delete(enrollment)
            try #expect(studyManager.scheduler.queryTasks(for: allTime).count == 1)
            try studyManager.removeOrphanedTasks()
        }
        try await _Concurrency.Task.sleep(for: .seconds(0.2))
        try await MainActor.run {
            try #expect(studyManager.scheduler.queryTasks(for: allTime).isEmpty)
        }
    }
    
    @Test
    func orphanStudyBundleHandling() async throws {
        let fileManager = FileManager.default
        let studyManager = StudyManager(persistence: .inMemory)
        await withDependencyResolution(standard: TestStandard()) {
            Scheduler(persistence: .inMemory)
            studyManager
        }
        try await studyManager.enroll(in: studyBundle)
        try await MainActor.run {
            #expect(studyManager.studyEnrollments.count == 1)
            let enrollment = try #require(studyManager.studyEnrollments.first)
            #expect(enrollment.studyId == studyBundle.id)
            #expect(enrollment.studyId == studyBundle.studyDefinition.id)
            #expect(try #require(enrollment.studyBundle).studyDefinition == studyBundle.studyDefinition)
            #expect(try fileManager.contents(of: StudyManager.studyBundlesDirectory).contains(enrollment.studyBundleUrl))
            studyManager.modelContext.delete(enrollment)
            #expect(try fileManager.contents(of: StudyManager.studyBundlesDirectory).contains(enrollment.studyBundleUrl))
            try studyManager.removeOrphanedTasks() // not what we're testing but important to ensure that the test doesn't crash
            try studyManager.removeOrphanedStudyBundles()
            #expect(try !fileManager.contents(of: StudyManager.studyBundlesDirectory).contains(enrollment.studyBundleUrl))
        }
    }
    
    
    deinit {
        try? FileManager.default.removeItem(at: studyBundle.bundleUrl)
    }
}
