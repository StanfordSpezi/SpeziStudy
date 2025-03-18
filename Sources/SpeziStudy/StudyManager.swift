//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Combine
@preconcurrency import FirebaseFirestore
@preconcurrency import FirebaseStorage
import Foundation
import class ModelsR4.Questionnaire
import class ModelsR4.QuestionnaireResponse
import Observation
import PDFKit
import Spezi
import SpeziAccount
import SpeziFirebaseConfiguration
import SpeziHealthKit
import SpeziScheduler
import SpeziSchedulerUI
@_exported import SpeziStudyDefinition
import SwiftData
import SwiftUI
import HealthKitOnFHIR


public struct SimpleError: Error, LocalizedError {
    let message: String
    
    init(_ message: String) {
        self.message = message
    }
    
    public var errorDescription: String? {
        message
    }
}


@Observable
@MainActor // TODO can we easily make this sendable w/out it also being MainActor-constrained?
public final class StudyManager: Module, EnvironmentAccessible, Sendable {
    @ObservationIgnored @Dependency(Account.self) private var account
    @ObservationIgnored @Dependency(HealthKit.self) private var healthKit
    @ObservationIgnored @Dependency(Scheduler.self) private var scheduler
    @ObservationIgnored @Dependency(FirebaseConfiguration.self) private var firebaseConfiguration
    
    @ObservationIgnored @Application(\.logger) private var logger
    
    #if targetEnvironment(simulator)
    @ObservationIgnored private var autosaveTask: _Concurrency.Task<Void, Never>?
    #endif
    
    let modelContainer: ModelContainer
    
    var modelContext: ModelContext {
        modelContainer.mainContext
    }
    
    private(set) var SPCs: [StudyParticipationContext] = []
    
    private(set) public var actionCards: [ActionCard] = []
    
    
    public init() {
        modelContainer = { () -> ModelContainer in
            ValueTransformer.setValueTransformer(
                JSONEncodingValueTransformer<QuestionnaireResponse>(),
                forName: .init("JSONEncodingValueTransformer<QuestionnaireResponse>")
            )
            let schema = Schema([
                StudyParticipationContext.self, SPCQuestionnaireEntry.self
            ])
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
            SPCs = try modelContext.fetch(FetchDescriptor<StudyParticipationContext>())
            try registerStudyTasksWithScheduler(SPCs)
            try await setupStudyBackgroundComponents(SPCs)
            // TODO(@lukas) we need a thing (not here, probably in -configre or in the function that fetches the current study versions from the server) that deletes/stops all Tasks registered w/ the scheduler that don't correspond to valid study components anymore! eg: imagine we remove an informational component (or replace it w/ smth completely new). in that case we want to disable the schedule for that, instead of having it continue to run in the background!
            updateActionCards()
            
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
        NotificationCenter.default.publisher(for: ModelContext.didSave, object: modelContext)
            .sink { notification in
                // We use the mainContext. Therefore, the vent will always be called from the main actor
                MainActor.assumeIsolated {
                    consume(notification)
                }
            }
    }
}


extension StudyManager {
    private func updateActionCards() {
        actionCards = Array {
//            ActionCard.enrollInStudy
            // TODO have more suff here? maybe somehow allow the server to show these non-schedule-managed in-app action cards?
        }
    }
}


// MARK: Study Participation and Lifrecycle Management

extension StudyManager {
    public enum StudyEnrollmentError: Error, LocalizedError {
        /// The user tried to enroll into a study they are already enrolled in.
        case alreadyEnrolledInStudy
        /// The user tried to enroll into a study which defines a depdenency on some other study, which the user isn't enrolled in.
        case notEnrolledInDependency // TODO missingEnrollmentInStudyDependency?
        
        public var errorDescription: String? {
            switch self {
            case .alreadyEnrolledInStudy:
                "You already are enrolled in this study"
            case .notEnrolledInDependency:
                "You cannot enroll in this study at this time, because the study has a dependency on another study, which you are not enrolled in"
            }
        }
    }
    
    
    private func registerStudyTasksWithScheduler(_ SPCs: some Collection<StudyParticipationContext>) throws {
        for SPC in SPCs {
            for (idx, schedule) in SPC.study.schedule.elements.enumerated() { // TODO using the index to identify these is a horrible idea!!! (but i also don't wanna give them individual ids?...)
                guard let component: StudyDefinition.Component = SPC.study.component(withId: schedule.componentId) else {
                    throw SimpleError("Unable to find component for id '\(schedule.componentId)'")
                }
                guard component.requiresUserInteraction else {
                    // if this is an internal component, we don't want to schedule it via SpeziScheduler.
                    continue
                }
                let category: Task.Category?
                let action: ActionCard.Action?
                switch component {
                case .questionnaire(id: _, let questionnaire):
                    category = .questionnaire
                    action = .answerQuestionnaire(questionnaire, spcId: SPC.persistentModelID)
                case .informational(let component):
                    category = .informational
                    action = .presentInformationalStudyComponent(component)
                case .healthDataCollection:
                    fatalError()
                }
                let (task, _) = try scheduler.createOrUpdateTask(
                    id: "edu.stanford.spezi.SpeziStudy.studyComponentTask.\(SPC.study.id.uuidString).\(component.id)", // TOOD better schema here?!
                    title: component.displayTitle.map { "\($0)" } ?? "",
                    instructions: "",
                    category: category,
                    schedule: try .init(schedule, participationStartDate: SPC.enrollmentDate),
                    completionPolicy: schedule.completionPolicy,
                    scheduleNotifications: false, // TODO allow customizing this!! // TODO passing true here causes weird SwiftData crashes!!!
                    notificationThread: NotificationThread.none, // TODO!!!
                    tags: nil, // TODO?!
                    effectiveFrom: .now,
                    shadowedOutcomesHandling: .delete,
                    with: { context in
                        context.studyScheduledTaskAction = action
                    } // TODO use this for smth?
                )
                print("Scheduled task \(task)")
            }
        }
    }
    
    
    private func setupStudyBackgroundComponents(_ SPCs: some Collection<StudyParticipationContext>) async throws {
        for SPC in SPCs {
            for component in SPC.study.healthDataCollectionComponents {
                func setupSampleCollection(_ sampleTypes: some Collection<SampleType<some Any>>) async {
                    for sampleType in sampleTypes {
                        await healthKit.addHealthDataCollector(CollectSample(
                            sampleType,
                            start: .automatic,
                            continueInBackground: true,
                            predicate: nil
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
    
    
    // MARK: Study Enrollment
    public func enroll(in study: StudyDefinition) async throws {
        // TODO big issue in this function is that, if we throw somewhere we kinda need to unroll _all_ the changes we've made so far
        // (which is much easier said that done...)
        guard !SPCs.contains(where: { $0.study.id == study.id }) else {
            throw StudyEnrollmentError.alreadyEnrolledInStudy
        }
        
        if let dependency = study.metadata.studyDependency {
            guard SPCs.contains(where: { $0.study.id == dependency }) else {
                throw StudyEnrollmentError.notEnrolledInDependency
            }
        }
        
        let SPC = StudyParticipationContext(study: study)
        modelContext.insert(SPC)
        try modelContext.save()
        SPCs.append(SPC)
        print("ADDING TASKS FOR STUDY COMPONENTS")
        try registerStudyTasksWithScheduler(CollectionOfOne(SPC))
        try await setupStudyBackgroundComponents(CollectionOfOne(SPC))
    }
    
    
    public func unenroll(from SPC: StudyParticipationContext) async throws {
        // TODO
        // - remove SPC from db
        // - inform server
        // - delete all tasks belonging to this SPC
        throw SimpleError("Not yet implemented!!!")
        // TODO questions:
        // - if we allow re-enrolling into a previously-enrolled study, we need the ability to schedule the tasks and then
        //   immediately check as completed everything up to today?
        //   or would that be irrelevant since the event list only looks at today+ already?
    }
    
    
    public func SPC(withId id: PersistentIdentifier) -> StudyParticipationContext? {
        modelContext.registeredModel(for: id)
    }
    
    public func saveQuestionnaireResponse(_ response: QuestionnaireResponse, for SPC: StudyParticipationContext) throws {
        let entry = SPCQuestionnaireEntry(SPC: SPC, response: response)
        modelContext.insert(entry) // TODO QUESTION: does this cause the property in the SPC class to get updated???
    }
}


// MARK: Consent Documents

extension StudyManager {
    public enum ConsentDocumentContext {
        /// The user has consented to the app in general
        case generalAppUsage
        /// The user has consented to participation in the specified study.
        case studyEnrolment(StudyDefinition)
    }
    
    public func importConsentDocument(_ pdf: PDFDocument, for context: ConsentDocumentContext) async throws {
        guard let accountId = account.details?.accountId else {
            logger.error("Unable to get account id. not uploading consent form.")
            return
        }
        guard let pdfData = pdf.dataRepresentation() else {
            logger.error("Unable to get PDF data. not uploading consent form.")
            return
        }
        let storageRef = Storage.storage().reference(withPath: "users/\(accountId)/consent/\(UUID().uuidString).pdf")
        let metadata = StorageMetadata()
        metadata.contentType = "application/pdf"
        // TODO add some more metadata?
        try await storageRef.putDataAsync(pdfData, metadata: metadata)
    }
}


// MARK: Health Import

extension StudyManager {
    public func handleNewHealthSample(_ sample: HKSample) async {
        // TODO instead of performing the upload right in here, maybe add it to a queue and
        // have a background task that just goes over the queue until its empty?
        do {
            try await healthKitDocument(id: sample.uuid)
                .setData(from: sample.resource)
        } catch {
            logger.error("Error saving HealthKit sample to Firebase: \(error)")
            // TODO queue sample for later retry?
        }
    }
    
    
    public func handleDeletedHealthObject(_ object: HKDeletedObject) async {
        // TODO
        do {
            try await healthKitDocument(id: object.uuid).delete()
        } catch {
            logger.error("Error saving HealthKit sample to Firebase: \(error)")
            // TODO queue for later retry?
        }
    }
    
    
    private func healthKitDocument(id uuid: UUID) async throws -> DocumentReference {
        try await firebaseConfiguration.userDocumentReference
            .collection("HealthKitObservations") // Add all HealthKit sources in a /HealthKit collection.
            .document(uuid.uuidString) // Set the document identifier to the UUID of the document.
    }
}


// MARK: Other


extension Task.Context {
    // TODO for some reason only .json works? .propertyList (the default) fails to decode the input?!
    @Property(coding: .json) public var studyScheduledTaskAction: StudyManager.ActionCard.Action?
}


extension Task.Category {
    public static let informational = Self.custom("edu.stanford.spezi.SpeziStudy.task.informational")
}


extension View {
    public func injectingCustomTaskCategoryAppearances() -> some View {
        self
            .taskCategoryAppearance(for: .informational, label: "Informational", image: .system("text.rectangle.page"))
//            .taskCategoryAppearance(for: .informational, label: "Informational", image: .systemSymbol(.textRectanglePage))
    }
}



extension SpeziScheduler.Schedule {
    /// - parameter other: the study definition schedule element which should be turned into a `Schedule`
    /// - parameter participationStartDate: the date at which the user started to participate in the study.
    init(_ other: StudyDefinition.ScheduleElement, participationStartDate: Date) throws {
        switch other.scheduleKind {
        case .once(.studyBegin, let offset):
            self = .once(at: participationStartDate.advanced(by: offset.totalSeconds))
        case .once(.studyEnd, _):
            // TODO instead of throwing an error here, we probably wanna return nil,
            // since this is something where we do want to continue processing the remaining schedule elements!!!
            throw SimpleError(".once(.studyEnd) not supported!")
        case .once(.completion, offset: _):
            throw SimpleError(".once(.completionOf) not (yet?!) supported!")
        case let .repeated(.daily(interval, hour, minute), startOffsetInDays):
            self = .daily(
                interval: interval,
                hour: hour,
                minute: minute,
                second: 0,
                startingAt: participationStartDate.addingTimeInterval(60 * 60 * 24 * TimeInterval(startOffsetInDays)),
                end: .never,
                duration: .tillEndOfDay
            )
        case let .repeated(.weekly(interval, weekday, hour, minute), startOffsetInDays):
            self = .weekly(
                interval: interval,
                weekday: weekday,
                hour: hour,
                minute: minute,
                second: 0,
                startingAt: participationStartDate.addingTimeInterval(60 * 60 * 24 * TimeInterval(startOffsetInDays)),
                end: .never,
                duration: .tillEndOfDay
            )
        default:
            fatalError()
        }
    }
}

