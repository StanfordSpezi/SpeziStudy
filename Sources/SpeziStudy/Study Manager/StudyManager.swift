//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Combine
import Foundation
import HealthKitOnFHIR
import class ModelsR4.Questionnaire
import class ModelsR4.QuestionnaireResponse
import Observation
import PDFKit
import Spezi
import SpeziHealthKit
import SpeziLocalStorage
import SpeziScheduler
import SpeziSchedulerUI
@_exported import SpeziStudyDefinition
import SwiftData
import SwiftUI


@available(*, deprecated, message: "Migrate to a dedicated Error type instead!")
struct SimpleError: Error, LocalizedError {
    let message: String
    
    var errorDescription: String? {
        message
    }
    
    init(_ message: String) {
        self.message = message
    }
}


@MainActor
public final class StudyManager: Module, EnvironmentAccessible, Sendable {
    // swiftlint:disable attributes
    @ObservationIgnored @Dependency(HealthKit.self) var healthKit
    @ObservationIgnored @Dependency(Scheduler.self) var scheduler
    @ObservationIgnored @Application(\.logger) var logger
    // swiftlint:enaable attributes
    
    #if targetEnvironment(simulator)
    @ObservationIgnored private var autosaveTask: _Concurrency.Task<Void, Never>?
    #endif
    
    let modelContainer: ModelContainer
    
    var modelContext: ModelContext {
        ModelContext(modelContainer)
    }
    
    
    public init() {
        modelContainer = { () -> ModelContainer in
            let schema = Schema([StudyParticipationContext.self], version: Schema.Version(0, 0, 1))
            let config = ModelConfiguration(
                "SpeziStudy",
                schema: schema,
                url: URL.documentsDirectory.appendingPathComponent("edu.stanford.spezi.studymanager.storage.sqlite"),
                allowsSave: true,
                cloudKitDatabase: .none
            )
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }()
    }
    
    
    public func configure() {
        _Concurrency.Task { @MainActor in
            let SPCs = try modelContext.fetch(FetchDescriptor<StudyParticipationContext>())
            try registerStudyTasksWithScheduler(SPCs)
            try await setupStudyBackgroundComponents(SPCs)
            // TODO(@lukas) we need a thing (not here, probably in -configre or in the function that fetches the current study versions from the server) that deletes/stops all Tasks registered w/ the scheduler that don't correspond to valid study components anymore! eg: imagine we remove an informational component (or replace it w/ smth completely new). in that case we want to disable the schedule for that, instead of having it continue to run in the background!
            
            #if targetEnvironment(simulator)
            guard autosaveTask == nil else {
                return
            }
            autosaveTask = _Concurrency.Task.detached {
                while true {
                    await MainActor.run {
                        try? self.modelContext.save()
                    }
                    try? await _Concurrency.Task.sleep(for: .seconds(0.25))
                }
            }
            #endif
        }
    }
    
    
    @MainActor
    func sinkDidSavePublisher(into consume: @MainActor @escaping (Notification) -> Void) throws -> AnyCancellable {
        NotificationCenter.default.publisher(for: ModelContext.didSave, object: modelContainer.mainContext)
            .sink { notification in
                // We use the mainContext. Therefore, the vent will always be called from the main actor
                MainActor.assumeIsolated {
                    consume(notification)
                }
            }
    }
}


// MARK: Study Participation and Lifeecycle Management

extension StudyManager {
    public enum StudyEnrollmentError: Error, LocalizedError {
        /// The user tried to enroll into a study they are already enrolled in.
        case alreadyEnrolledInStudy
        /// The user tried to enroll into a study which defines a depdenency on some other study, which the user isn't enrolled in.
        case missingEnrollmentInStudyDependency
        
        public var errorDescription: String? {
            switch self {
            case .alreadyEnrolledInStudy:
                "You already are enrolled in this study"
            case .missingEnrollmentInStudyDependency:
                "You cannot enroll in this study at this time, because the study has a dependency on another study, which you are not enrolled in"
            }
        }
    }
    
    
    @MainActor
    private func registerStudyTasksWithScheduler(_ SPCs: some Collection<StudyParticipationContext>) throws {
        for SPC in SPCs {
            guard let study = SPC.study else {
                continue
            }
            for schedule in study.schedule.elements {
                guard let component: StudyDefinition.Component = study.component(withId: schedule.componentId) else {
                    throw SimpleError("Unable to find component for id '\(schedule.componentId)'")
                }
                guard component.requiresUserInteraction else {
                    // if this is an internal component; we don't want to schedule it via SpeziScheduler.
                    continue
                }
                let category: Task.Category?
                let action: ScheduledTaskAction?
                switch component {
                case .questionnaire(let component):
                    category = .questionnaire
                    action = .answerQuestionnaire(component.questionnaire, spcId: SPC.persistentModelID)
                case .informational(let component):
                    category = .informational
                    action = .presentInformationalStudyComponent(component)
                case .healthDataCollection:
                    continue
                }
                try scheduler.createOrUpdateTask(
                    id: taskId(for: component, in: study),
                    title: component.displayTitle.map { "\($0)" } ?? "",
                    instructions: "",
                    category: category,
                    schedule: try .init(schedule, participationStartDate: SPC.enrollmentDate),
                    completionPolicy: schedule.completionPolicy,
                    // not passing true here currently, since that sometimes leads to SwiftData crashes (for some inputs)
                    scheduleNotifications: false,
                    notificationThread: NotificationThread.none,
                    tags: nil,
                    effectiveFrom: .now,
                    shadowedOutcomesHandling: .delete,
                    with: { context in
                        context.studyScheduledTaskAction = action
                    }
                )
            }
        }
    }
    
    @MainActor
    private func setupStudyBackgroundComponents(_ SPCs: some Collection<StudyParticipationContext>) async throws {
        for SPC in SPCs {
            guard let study = SPC.study else {
                continue
            }
            for component in study.healthDataCollectionComponents {
                func setupSampleCollection(_ sampleTypes: some Collection<SampleType<some Any>>) async {
                    for sampleType in sampleTypes {
                        await healthKit.addHealthDataCollector(CollectSample(
                            sampleType,
                            start: .automatic,
                            continueInBackground: true
                        ))
                    }
                }
                await setupSampleCollection(component.sampleTypes.quantityTypes)
                await setupSampleCollection(component.sampleTypes.correlationTypes.flatMap(\.associatedQuantityTypes))
                await setupSampleCollection(component.sampleTypes.categoryTypes)
            }
        }
        // we want to request HealthKit auth once, at the end, for everything we just registered.
        try await healthKit.askForAuthorization()
    }
    
    
    private func taskId(for component: StudyDefinition.Component, in study: StudyDefinition) -> String {
        "edu.stanford.spezi.SpeziStudy.studyComponentTask.\(study.id.uuidString).\(component.id)"
    }
    
    // MARK: Study Enrollment
    
    /// Enroll in a study.
    @MainActor
    public func enroll(in study: StudyDefinition) async throws {
        // big issue in this function is that, if we throw somewhere we kinda need to unroll _all_ the changes we've made so far
        // (which is much easier said that done...)
        let SPCs = try modelContext.fetch(FetchDescriptor<StudyParticipationContext>())
        
        guard !SPCs.contains(where: { $0.studyId == study.id }) else {
            throw StudyEnrollmentError.alreadyEnrolledInStudy
        }
        
        if let dependency = study.metadata.studyDependency {
            guard SPCs.contains(where: { $0.studyId == dependency }) else {
                throw StudyEnrollmentError.missingEnrollmentInStudyDependency
            }
        }
        
        let SPC = StudyParticipationContext(enrollmentDate: .now, study: study)
        modelContext.insert(SPC)
        try modelContext.save()
        try registerStudyTasksWithScheduler(CollectionOfOne(SPC))
        try await setupStudyBackgroundComponents(CollectionOfOne(SPC))
    }
    
    
    /// Unenroll from a study.
    public func unenroll(from SPC: StudyParticipationContext) async throws {
        let study = SPC.study!
        modelContext.delete(SPC)
        for component in study.components {
            try await scheduler.deleteAllVersions(ofTask: taskId(for: component, in: study))
        }
        // TODO
        // - remove SPC from db
        // - inform server
        // - delete all tasks belonging to this SPC
        throw SimpleError("Not yet implemented!!!")
        // QUESTIONS:
        // - if we allow re-enrolling into a previously-enrolled study, we need the ability to schedule the tasks and then
        //   immediately check as completed everything up to today?
        //   or would that be irrelevant since the event list only looks at today+ already?
    }
    
    
    /// Fetches the ``StudyParticipationContext`` for the specified `PersistentIdentifier`.
    public func SPC(withId id: PersistentIdentifier) -> StudyParticipationContext? {
        modelContext.registeredModel(for: id)
    }
}



extension StudyManager {
    /// Informs the Study Manager about current study definitions.
    ///
    /// Ths study manager will use these definitions to determine whether it needs to update any of the study participation contexts ic currently manages.
    public func informAboutStudies(_ studies: [StudyDefinition]) async throws {
        for study in studies {
            let studyId = study.id
            for SPC in try modelContext.fetch(FetchDescriptor(predicate: #Predicate<StudyParticipationContext> { $0.studyId == studyId })) {
                SPC.study
            }
        }
    }
//    func migrate(SPC: StudyParticipationContext2, to newStudyDef: StudyDefinition) async throws {
//        fatalError()
//    }
}


extension LocalStorageKeys {
    static let enrolledSPCs = LocalStorageKey("edu.stanford.spezi.studymanager.enrolledSPCs", setting: .unencrypted(excludeFromBackup: false))
}
