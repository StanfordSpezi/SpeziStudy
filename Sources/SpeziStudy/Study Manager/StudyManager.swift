//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Combine
import Foundation
import Spezi
import SpeziHealthKit
import SpeziLocalStorage
import SpeziScheduler
import SpeziSchedulerUI
@_exported import SpeziStudyDefinition
import SwiftData
import SwiftUI


@MainActor
public final class StudyManager: Module, EnvironmentAccessible, Sendable {
    /// How the ``StudyManager`` should persist its data.
    public enum PersistenceConfiguration {
        /// The ``StudyManager`` will use an on-disk database for persistence.
        case onDisk
        /// The ``StudyManager`` will use an in-memory database for persistence.
        /// Intended for testing purposes.
        case inMemory
    }
    
    // swiftlint:disable attributes
    @Dependency(HealthKit.self) var healthKit
    @Dependency(Scheduler.self) var scheduler
    @Application(\.logger) var logger
    // swiftlint:enaable attributes
    
    #if targetEnvironment(simulator)
    private var autosaveTask: _Concurrency.Task<Void, Never>?
    #endif
    
    let modelContainer: ModelContainer
    
    @MainActor
    var modelContext: ModelContext {
        modelContainer.mainContext
    }
    
    
    public init(persistence: PersistenceConfiguration = .onDisk) {
        modelContainer = { () -> ModelContainer in
            let schema = Schema([StudyParticipationContext.self], version: Schema.Version(0, 0, 1))
            let config: ModelConfiguration
            switch persistence {
            case .onDisk:
                config = ModelConfiguration(
                    "SpeziStudy",
                    schema: schema,
                    url: URL.documentsDirectory.appendingPathComponent("edu.stanford.spezi.studymanager.storage.sqlite")
                )
            case .inMemory:
                config = ModelConfiguration("SpeziStudy", schema: schema, isStoredInMemoryOnly: true)
            }
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
        /// The user tried to enroll into a study with revision `X`, but they are already enrolled in revision `Y > X`.
        case alreadyEnrolledInNewerStudyRevision
        /// The user tried to enroll into a study which defines a depdenency on some other study, which the user isn't enrolled in.
        case missingEnrollmentInStudyDependency
        
        public var errorDescription: String? {
            switch self {
            case .alreadyEnrolledInNewerStudyRevision:
                "Already enrolled in a newer version of this study"
            case .missingEnrollmentInStudyDependency:
                "Cannot enroll in this study at this time, because the study has a dependency on another study, which the user is not enrolled in"
            }
        }
    }
    
    
    @MainActor // swiftlint:disable:next function_body_length
    private func registerStudyTasksWithScheduler(_ SPCs: some Collection<StudyParticipationContext>) throws {
        for SPC in SPCs {
            guard let study = SPC.study else {
                continue
            }
            var createdTasks = Set<Task>()
            for schedule in study.schedule.elements {
                guard let component: StudyDefinition.Component = study.component(withId: schedule.componentId) else {
                    // ideally this shouldn't happen, but if it does (we have a schedule but can't resolve the corresponding component),
                    // we simply skip and ignore it.
                    continue
                }
                switch component.kind {
                case .userInteractive:
                    // user-interactive components get scheduled as Scheduler Tasks ...
                    break
                case .internal:
                    // ... but internal components don't
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
                let (task, didChange) = try scheduler.createOrUpdateTask(
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
                print("\(String(localized: task.title)) didChange: \(didChange)")
                createdTasks.insert(task)
            }
            
            let activeTaskIds = createdTasks.mapIntoSet(\.id)
            let prefix = taskIdPrefix(for: study)
            let orphanedTasks = (try? scheduler.queryTasks(for: Date.distantPast...Date.distantFuture, predicate: #Predicate<Task> {
                // we filter for all tasks that are part of this study (determined based on prefix),
                // and are not among the tasks we just scheduled.
                // any task that exists in the scheduler and does not fulfill these criteria is a task that must have been scheduled
                // for a previous revision of the study, and belongs to a component that no longer exists
                $0.id.starts(with: prefix) && !activeTaskIds.contains($0.id)
            })) ?? []
            for orphanedTask in orphanedTasks {
                try scheduler.deleteAllVersions(of: orphanedTask)
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
    
    
    private func taskIdPrefix(for study: StudyDefinition) -> String {
        taskIdPrefix(forStudyId: study.id)
    }
    
    private func taskIdPrefix(forStudyId studyId: StudyDefinition.ID) -> String {
        "edu.stanford.spezi.SpeziStudy.studyComponentTask.\(studyId.uuidString)"
    }
    
    private func taskId(for component: StudyDefinition.Component, in study: StudyDefinition) -> String {
        "\(taskIdPrefix(for: study)).\(component.id)"
    }
    
    // MARK: Study Enrollment
    
    /// Enroll in a study.
    ///
    /// Once the device is enrolled into a study at revision `X`, subsequent ``enroll(in:)`` calls for the same study, with revision `Y`, will:
    /// - if `X = Y`: have no effect;
    /// - if `X < Y`: update the study enrollment, as if ``informAboutStudies(_:)`` was called with the new study revision;
    /// - if `X > Y`: throw an error.
    @MainActor
    public func enroll(in study: StudyDefinition) async throws {
        // big issue in this function is that, if we throw somewhere we kinda need to unroll _all_ the changes we've made so far
        // (which is much easier said than done...)
        let SPCs = try modelContext.fetch(FetchDescriptor<StudyParticipationContext>())
        
        if case let existingSPCs = SPCs.filter({ $0.studyId == study.id }),
           !existingSPCs.isEmpty {
            // There exists at least one enrollment for this study
            if let SPC = existingSPCs.first, existingSPCs.count == 1 {
                if SPC.studyRevision == study.studyRevision {
                    // already enrolled in this study, at this revision.
                    // this is a no-op.
                    return
                } else if SPC.studyRevision < study.studyRevision {
                    // if we have only one enrollment, and it is for an older version of the study,
                    // we treat the enroll call as a study definition update
                    try await informAboutStudies(CollectionOfOne(study))
                    return
                } else {
                    // SPC.studyRevision > study.studyRevision
                    // trying to enroll into an older version of the study.
                    throw StudyEnrollmentError.alreadyEnrolledInNewerStudyRevision
                }
            }
            throw StudyEnrollmentError.alreadyEnrolledInNewerStudyRevision
        }
        
        if let dependency = study.metadata.studyDependency {
            guard SPCs.contains(where: { $0.studyId == dependency }) else {
                throw StudyEnrollmentError.missingEnrollmentInStudyDependency
            }
        }
        
        let SPC = try StudyParticipationContext(enrollmentDate: .now, study: study)
        modelContext.insert(SPC)
        try modelContext.save()
        try registerStudyTasksWithScheduler(CollectionOfOne(SPC))
        try await setupStudyBackgroundComponents(CollectionOfOne(SPC))
    }
    
    
    /// Unenroll from a study.
    public func unenroll(from SPC: StudyParticipationContext) throws {
        do {
            // Delete all Tasks associated with this study.
            // Note that we do this by simply fetching & deleting all Tasks with a matching prefix,
            // instead of going (based on the study components) through all component ids and deleting the tasks based on that.
            // the reason being that we might be deleting an SPC w/ an old study schema, which we can't necessarily trivially decode.
            let studyTaskPrefix = taskIdPrefix(forStudyId: SPC.studyId)
            let tasks = try scheduler.queryTasks(for: Date.distantPast...Date.distantFuture, predicate: #Predicate {
                $0.id.starts(with: studyTaskPrefix)
            })
            for task in tasks {
                try scheduler.deleteAllVersions(of: task)
            }
        }
        modelContext.delete(SPC)
        try modelContext.save()
    }
    
    
    /// Fetches the ``StudyParticipationContext`` for the specified `PersistentIdentifier`.
    public func SPC(withId id: PersistentIdentifier) -> StudyParticipationContext? {
        // for some reason, simply doing `modelContext.registeredModel(for: id)` doesn't work...
        let SPCs = (try? modelContext.fetch(FetchDescriptor(predicate: #Predicate<StudyParticipationContext> {
            $0.persistentModelID == id
        }))) ?? []
        return SPCs.first
    }
}


extension StudyManager {
    /// Informs the Study Manager about current study definitions.
    ///
    /// Ths study manager will use these definitions to determine whether it needs to update any of the study participation contexts ic currently manages.
    public func informAboutStudies(_ studies: some Collection<StudyDefinition>) async throws {
        for study in studies {
            let studyId = study.id
            let studyRevision = study.studyRevision
            for SPC in try modelContext.fetch(FetchDescriptor(predicate: #Predicate<StudyParticipationContext> {
                $0.studyId == studyId && $0.studyRevision < studyRevision
            })) {
                try SPC.updateStudyDefinition(study)
                try registerStudyTasksWithScheduler(CollectionOfOne(SPC))
                try await setupStudyBackgroundComponents(CollectionOfOne(SPC))
            }
        }
    }
}
