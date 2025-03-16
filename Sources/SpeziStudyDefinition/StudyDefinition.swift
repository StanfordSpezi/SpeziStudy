//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
@preconcurrency import ModelsR4
import SpeziHealthKit
import SpeziScheduler
import HealthKit
import DequeModule



/// Something that can appear in a `StudyDefinition`
public typealias StudyDefinitionElement = Hashable & Codable & Sendable


public struct StudyDefinition: Identifiable, StudyDefinitionElement {
    public var metadata: Metadata
    public var components: [Component]
    public var schedule: Schedule
    
    public var id: UUID { metadata.id }
    
    public init(metadata: Metadata, components: [Component], schedule: Schedule) {
        self.metadata = metadata
        self.components = components
        self.schedule = schedule
    }
}



extension StudyDefinition {
    public struct Metadata: Identifiable, StudyDefinitionElement {
        public enum Icon: StudyDefinitionElement {
            case systemSymbol(String)
            case custom(Data)
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
        public var explanationText: String // TODO rename introductionText? introductoryText? instructions?
        
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
            icon: Icon? = nil,
            shortExplanationText: String,
            explanationText: String,
            studyDependency: StudyDefinition.ID? = nil,
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



extension StudyDefinition {
    public struct ParticipationCriteria: StudyDefinitionElement {
//        public struct Region: Codable, StudyDefinitionElement {
//            public let name: String
//            public let subRegions: [Region]
//            public init(name: String, subRegions: [Region] = []) {
//                self.name = name
//                self.subRegions = subRegions
//            }
//
//            public static let us = Self(name: "US", subRegions: <#T##[StudyDefinition.ParticipationCriteria.Region]#>)
//            public static let uk = Self(rawValue: 1 << 1)
//            public static let de = Self(rawValue: 1 << 2)
//            public static let ca = Self(rawValue: 1 << 3)
//            public static let northAmerica: Self = [.us, .ca]
//            public static let unknown: Self = []
//        }
        
        /// A criterion which must be satisfied for a person to be able to participate in a study.
        ///
        /// TODO might want to add the concept of public/internal criterions (public would be ones which are communicated to the user / the user can know about; internal would be for e.g. inter-study dependencies)
        public indirect enum Criterion: StudyDefinitionElement {
            /// a criterion which evaluates to true if the user is at least of the specified age
            case ageAtLeast(Int)
            /// a criterion which evaluates to true if the user is from the specified region
            case isFromRegion(Locale.Region)
            /// a criterion which evaluates to true if the user speaks the specified language
            case speaksLanguage(Locale.Language)
//            /// a criterion which evaluates to true if the user is overweight
//            case isOverweight
            /// a criterion which evaluates to true based on a custom condition
            case custom(CustomCriterionKey)
//            /// a criterion which always evaluates to true
//            case `true`
            
            /// a criterion which evaluates to true iff its contained criterion evaluates to false.
            case not(Criterion)
            /// a criterion which evaluates to true iff all of its contained criteria evaluate to true
            /// - Note: if the list of contained criteria is empty, the criterion will evaluate to true
            case all([Criterion])
            /// a criterion which evaluates to true iff any of its contained criteria evaluates to true
            /// - Note: if the list of contained criteria is empty, the criterion will evaluate to false
            case any([Criterion])
            
            public static prefix func ! (rhs: Self) -> Self {
                .not(rhs)
            }
            public static func && (lhs: Self, rhs: Self) -> Self {
                .all([lhs, rhs])
            }
            public static func || (lhs: Self, rhs: Self) -> Self {
                .any([lhs, rhs])
            }
            
            /// whether the criterion is a leaf element, i.e. doesn't contain any nested further criteria
            public var isLeaf: Bool {
                switch self {
                case .ageAtLeast, .isFromRegion, .speaksLanguage, .custom:
                    true
                case .not, .any, .all:
                    false
                }
            }
            
            public var children: [Criterion] {
                switch self {
                case .ageAtLeast, .isFromRegion, .speaksLanguage, .custom:
                    []
                case .not(let inner):
                    [inner]
                case .any(let nested), .all(let nested):
                    nested
                }
            }
            
            public func reduce<Result>(into initialResult: Result, _ visitor: (inout Result, Criterion) throws -> Void) rethrows -> Result {
                var result = initialResult
                var deque: Deque<Self> = [self]
                while let node = deque.popFirst() {
                    try visitor(&result, node)
                    deque.append(contentsOf: node.children)
                }
                return result
            }
            
            public var allLeafs: Set<Criterion> {
                reduce(into: []) { leafs, criterion in
                    if criterion.isLeaf {
                        leafs.insert(criterion)
                    }
                }
            }
            
            public struct CustomCriterionKey: Codable, Hashable, Sendable {
                public let keyValue: String
                public let displayTitle: String
                public init(_ keyValue: String, displayTitle: String) {
                    self.keyValue = keyValue
                    self.displayTitle = displayTitle
                }
            }
        }
        
        private var criterionData: Data
        
        public var criterion: Criterion {
            @storageRestrictions(initializes: criterionData)
            init {
                criterionData = try! JSONEncoder().encode(newValue)
            }
            set {
                criterionData = try! JSONEncoder().encode(newValue)
            }
            get {
                try! JSONDecoder().decode(Criterion.self, from: criterionData)
            }
        }
        
        public init(criterion: Criterion) {
            self.criterion = criterion
        }
    }
}


extension StudyDefinition {
    /// Defines how enrollment into a study works
    public enum EnrollmentConditions: StudyDefinitionElement {
        /// The are no conditions wrt the enrollment into the study
        case none
        /// Enrollment into the study is controlled based on invitation codes.
        /// - parameter verificationEndpoint: URL to which a user-entered verification code is sent,
        ///     to determine whether the user should be allowed to enroll into the study.
        ///
        /// Example: you could have `https://my-heart-counts.stanford.edu/api/invite` as the endpoint here,
        /// and the app would then send a GET request to `/api/invite?code=${CODE}` to verify a user-entered invitation code
        ///
        /// TODO question here: how should these invitation-only studies be surfaced in the app?
        /// - we could have a hidden button of sorts, which one would use bring up a text field to enter the code,
        ///     which would need to somehow have the specific study it belongs to encoded into it (eg `MHCb:1234`, and anything prior to the `:` would be a shorthand study identifier)
        /// - OR: we could have a link-based mechanism, where we can tell the app to download a specific stufy from some url (or, maybe simply tell it to show some already-downloaded study which until now was always hidden)
        /// - the link could also directly include the personalized invitation code, so that the user wouldn't have to enter it by hand.
        case requiresInvitation(verificationEndpoint: URL)
    }
}




// MARK: Components

extension StudyDefinition {
    public enum Component: Identifiable, StudyDefinitionElement {
        case informational(InformationalComponent)
        /// - parameter id: the id of this study component, **not** of the questionnaire
        case questionnaire(id: UUID, questionnaire: Questionnaire)
        case healthDataCollection(HealthDataCollectionComponent)
        
        public var id: UUID {
            switch self {
            case .informational(let component):
                component.id
            case .healthDataCollection(let component):
                component.id
            case .questionnaire(let id, _):
                id
            }
        }
        
        /// Whether the component consists of something that we want the user to interact with
        ///
        /// TODO better name here. the idea is to differentiate between "internal" components (eg health data collection) that can run on their own,
        /// vc non-internal components that essentially just tell the user to do something.
        public var requiresUserInteraction: Bool {
            switch self {
            case .informational, .questionnaire:
                true
            case .healthDataCollection:
                false
            }
        }
    }
    
    
    public struct InformationalComponent: Identifiable, StudyDefinitionElement {
        public let id: UUID
        public let title: String
        public let headerImage: String // TODO find smth better here!!!
        public let body: String
        
        public init(id: UUID, title: String, headerImage: String, body: String) {
            self.id = id
            self.title = title
            self.headerImage = headerImage
            self.body = body
        }
    }
    
    
    public struct HealthDataCollectionComponent: Identifiable, StudyDefinitionElement {
        public let id: UUID
        public let sampleTypes: HealthSampleTypesCollection
        
        public init(id: UUID, sampleTypes: HealthSampleTypesCollection) {
            self.id = id
            self.sampleTypes = sampleTypes
        }
    }
}




// MARK: Schedule

extension StudyDefinition {
    public struct Schedule: StudyDefinitionElement { // TODO just use an array instead?
        public var elements: [ScheduleElement]
        
        public init(elements: [ScheduleElement]) {
            self.elements = elements
        }
    }
    
    
    public enum ScheduleKind: StudyDefinitionElement { // TODO better name!!!
        /// The base, relative to which a relatiive point in time is defined
        public enum RelativePointInTimeBase: StudyDefinitionElement {
            /// When the participant enrolls in the study, or when the study begins
            case studyBegin
            /// when the participant leaves the study, when the study officially ends
            case studyEnd
            // TODO/NOTE explain that this can in fact happen multiple times, even though it's called "once" (this is intentional, and makes sense, and it what we want/need)
            case completion(of: StudyDefinition.Component.ID)
        }
        
        public enum RecurrenceRuleInput: StudyDefinitionElement {
            case daily(interval: Int = 1, hour: Int, minute: Int = 0)
            case weekly(interval: Int = 1, weekday: Locale.Weekday, hour: Int, minute: Int = 0) // TODO optional weekday? non-optional?
        }
        /// The schedule should run once, relative to the specified base
        case once(RelativePointInTimeBase, offset: Swift.Duration = .seconds(0))
//        /// The schedule should run a certain time interval after the completion of some component.
//        /// E.g., this could be used to model a schedule where the user should perform some action N days after it was last performed
//        /// TODO advantages of this over a simple "every N days" schedule? (i guess the fact that if the user misses it once, they wouldn't have to wait N days until the next occurrence...)
//        /// TODO: better types/modelling for the referenced other component and the offset!
//        /// TODO difference between this and once
//        case relativeToCompletion(of: StudyDefinition.Component.ID, offset: TimeInterval)
        case repeated(RecurrenceRuleInput, startOffsetInDays: Int)
//        case daily(hour: Int, minute: Int)
//        case custom(SpeziScheduler.Schedule) // TODO bring this back!
        
//        public static func daily(
//            hour: Int,
//            minute: Int = 0,
//            interval: Int = 1,
//            startOffsetInDays: Int,
//            until end: Calendar.RecurrenceRule.End = .never
//        ) -> Self {
//            // TODO THE Calendar.current here is horrendous, since we might be creating the schedule in a different locale/timezone/calendar than when it'll get answered!!!
//            // THIS IS ALSO AN ISSUE WITH SPEZISCHEDULE, I'D IMAGINE??? (TODO @Lukas ask Andreas about this!!!)
//            .repeated(
////                .daily(calendar: .current, interval: interval, end: end, hours: [hour], minutes: [minute]),
//                .daily(interval: <#T##Int#>, hour: <#T##Int#>, minute: <#T##Int#>)
//                startOffsetInDays: startOffsetInDays
//            )
////            Calendar.RecurrenceRule.weekly(calendar: <#T##Calendar#>, interval: <#T##Int#>, end: <#T##Calendar.RecurrenceRule.End#>, matchingPolicy: <#T##Calendar.MatchingPolicy#>, repeatedTimePolicy: <#T##Calendar.RepeatedTimePolicy#>, months: <#T##[Calendar.RecurrenceRule.Month]#>, weekdays: <#T##[Calendar.RecurrenceRule.Weekday]#>, hours: <#T##[Int]#>, minutes: <#T##[Int]#>, seconds: <#T##[Int]#>, setPositions: <#T##[Int]#>)
//        }
//
//        public static func weekly(
//            day: Calendar.RecurrenceRule.Weekday,
//            hour: Int,
//            minute: Int = 0,
//            interval: Int = 1,
//            startOffsetInDays: Int,
//            until end: Calendar.RecurrenceRule.End = .never
//        ) -> Self {
//            // TODO THE Calendar.current here is horrendous, since we might be creating the schedule in a different locale/timezone/calendar than when it'll get answered!!!
//            // THIS IS ALSO AN ISSUE WITH SPEZISCHEDULE, I'D IMAGINE??? (TODO @Lukas ask Andreas about this!!!)
//            .repeated(
//                .weekly(calendar: .current, interval: interval, end: end, weekdays: [day], hours: [hour], minutes: [minute]),
//                startOffsetInDays: startOffsetInDays
//            )
//        }
        
//        private func toSpeziSchedule() -> SpeziScheduler.Schedule {
//            return .daily(hour: <#T##Int#>, minute: <#T##Int#>, startingAt: <#T##Date#>)
//        }
    }
    
    public struct ScheduleElement: StudyDefinitionElement {
        /// The identifier of the component this schedule is for
        public var componentId: StudyDefinition.Component.ID
        public var scheduleKind: ScheduleKind
        public var completionPolicy: SpeziScheduler.AllowedCompletionPolicy
        
        
        public init(componentId: StudyDefinition.Component.ID, scheduleKind: ScheduleKind, completionPolicy: SpeziScheduler.AllowedCompletionPolicy) {
            self.componentId = componentId
            self.scheduleKind = scheduleKind
            self.completionPolicy = completionPolicy
        }
    }
}




extension Calendar.RecurrenceRule: Hashable {
    public func hash(into hasher: inout Hasher) {
        for child in Mirror(reflecting: self).children {
            if let hashable = child.value as? any Hashable {
                hashable.hash(into: &hasher)
            } else {
                fatalError("Cannot hash child \(child)")
            }
        }
    }
}


extension Calendar.RecurrenceRule.Weekday: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .every(let weekday):
            hasher.combine(weekday)
        case .nth(let int, let weekday):
            hasher.combine(int)
            hasher.combine(weekday)
        @unknown default:
            fatalError()
        }
    }
}



// MARK: Other



public struct HealthSampleTypesCollection: StudyDefinitionElement {
    private enum CodingKeys: CodingKey {
        case quantityTypes
        case correlationTypes
        case categoryTypes
//        case other
    }
    
    private enum CodingError: Error {
        case unableToFindSampleType((any _HKSampleWithSampleType).Type, identifier: String)
    }
    
    public let quantityTypes: Set<SampleType<HKQuantitySample>>
    public let correlationTypes: Set<SampleType<HKCorrelation>>
    public let categoryTypes: Set<SampleType<HKCategorySample>>
//    public let other: Set<HKObjectType>
    
    public init(
        quantityTypes: Set<SampleType<HKQuantitySample>> = [],
        correlationTypes: Set<SampleType<HKCorrelation>> = [],
        categoryTypes: Set<SampleType<HKCategorySample>> = []//,
//        other: Set<HKObjectType> = []
    ) {
        self.quantityTypes = quantityTypes
        self.correlationTypes = correlationTypes
        self.categoryTypes = categoryTypes
//        self.other = other
    }
    
    public func merging(with other: Self) -> Self {
        Self(
            quantityTypes: self.quantityTypes.union(other.quantityTypes),
            correlationTypes: self.correlationTypes.union(other.correlationTypes),
            categoryTypes: self.categoryTypes.union(other.categoryTypes)//,
            //other: self.other.union(other.other)
        )
    }
    
    public mutating func merge(with other: Self) {
        self = self.merging(with: other)
    }
    
    
    public var isEmpty: Bool {
        quantityTypes.isEmpty && correlationTypes.isEmpty && categoryTypes.isEmpty //&& other.isEmpty
    }
    
    
    public init(from decoder: any Decoder) throws {
        func mapRawValuesIntoSampleTypes<T>(
            makeSampleType: (String) -> SampleType<T>?,
            rawIdentifiers: Set<String>
        ) throws -> Set<SampleType<T>> {
            var sampleTypes: Set<SampleType<T>> = []
            for identifier in rawIdentifiers {
                if let sampleType = makeSampleType(identifier) {
                    sampleTypes.insert(sampleType)
                } else {
                    throw CodingError.unableToFindSampleType(T.self as! (any _HKSampleWithSampleType).Type, identifier: identifier)
                }
            }
            return sampleTypes
        }
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        quantityTypes = try mapRawValuesIntoSampleTypes(
            makeSampleType: { SampleType<HKQuantitySample>(HKQuantityTypeIdentifier(rawValue: $0)) },
            rawIdentifiers: try container.decode(Set<String>.self, forKey: .quantityTypes)
        )
        correlationTypes = try mapRawValuesIntoSampleTypes(
            makeSampleType: { SampleType<HKCorrelation>(HKCorrelationTypeIdentifier(rawValue: $0)) },
            rawIdentifiers: try container.decode(Set<String>.self, forKey: .correlationTypes)
        )
        categoryTypes = try mapRawValuesIntoSampleTypes(
            makeSampleType: { SampleType<HKCategorySample>(HKCategoryTypeIdentifier(rawValue: $0)) },
            rawIdentifiers: try container.decode(Set<String>.self, forKey: .categoryTypes)
        )
//        other = try container.decode(Set<String>.self, forKey: .other).map { HKWorkoutType }
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(quantityTypes.map(\.identifier.rawValue), forKey: .quantityTypes)
        try container.encode(correlationTypes.map(\.identifier.rawValue), forKey: .correlationTypes)
        try container.encode(categoryTypes.map(\.identifier.rawValue), forKey: .categoryTypes)
    }
}


extension HealthKit.DataAccessRequirements {
    public init(_ other: HealthSampleTypesCollection) {
//        await setupSampleCollection(component.sampleTypes.quantityTypes)
//        await setupSampleCollection(component.sampleTypes.correlationTypes.flatMap(\.associatedQuantityTypes))
//        await setupSampleCollection(component.sampleTypes.categoryTypes)
        let sampleTypes = Set<HKSampleType> {
            other.quantityTypes.lazy.map(\.hkSampleType)
            other.categoryTypes.lazy.map(\.hkSampleType)
            other.correlationTypes.lazy.flatMap(\.associatedQuantityTypes).map(\.hkSampleType)
        }
        self.init(read: sampleTypes)
    }
}




// MARK: Criterion Eval

extension StudyDefinition.ParticipationCriteria.Criterion {
    public struct EvaluationEnvironment {
        let age: Int?
        let region: Locale.Region?
        let language: Locale.Language
        let enabledCustomKeys: Set<CustomCriterionKey>
        
        public init(
            age: Int?,
            region: Locale.Region?,
            language: Locale.Language,
            enabledCustomKeys: Set<CustomCriterionKey>
        ) {
            self.age = age
            self.region = region
            self.language = language
            self.enabledCustomKeys = enabledCustomKeys
        }
    }
    
    
    public func evaluate(_ environment: EvaluationEnvironment) -> Bool {
        switch self {
        case .ageAtLeast(let minAge):
            if let age = environment.age {
                return age >= minAge
            } else {
                return false
            }
        case .isFromRegion(let allowedRegion):
            if let region = environment.region {
                return region == allowedRegion
            } else {
                return false
            }
        case .speaksLanguage(let language):
            return language == environment.language
        case .custom(let key):
            return environment.enabledCustomKeys.contains(key)
        case .not(let criterion):
            return !criterion.evaluate(environment)
        case .any(let criteria):
            return criteria.contains { $0.evaluate(environment) }
        case .all(let criteria):
            return criteria.allSatisfy { $0.evaluate(environment) }
        }
    }
    
    
    // TODO?!
//    public func optimized() -> Self {
//        switch self {
//        case .ageAtLeast, .isFromRegion, .custom:
//            // can't do anything here
//            return self
//        case .not(let criterion):
//            switch criterion.optimized() {
//            case .not(let criterion):
//                return criterion // double not will cancel out
//            case .all(let criteria):
//
//            }
//        case .all(let array):
//            <#code#>
//        case .any(let array):
//            <#code#>
//        }
//    }
}


//extension Locale.Region {
//    /// Determines whether the region is the same as the specified other region, or whether it is contained within the specified other region.
//    func isEqualOrContainedIn(_ other: Self) -> Bool {
//        Locale.Region.northernAmer
//    }
//}



// MARK: Accessing stuff in a study, etc

extension StudyDefinition {
    public func component(withId id: Component.ID) -> Component? {
        components.first { $0.id == id }
    }
    
    public var healthDataCollectionComponents: [HealthDataCollectionComponent] {
        components.compactMap { component in
            switch component {
            case .healthDataCollection(let component):
                component
            case .informational, .questionnaire:
                nil
            }
        }
    }
    
    public var allCollectedHealthData: HealthSampleTypesCollection {
        healthDataCollectionComponents.reduce(into: HealthSampleTypesCollection.init()) { acc, component in
            acc.merge(with: component.sampleTypes)
        }
    }
}


extension StudyDefinition.Component {
    public var displayTitle: String? { // TODO is this actually needed / smth we wanna define in here?
        switch self {
        case .informational(let component):
            return component.title
        case .questionnaire(_, let questionnaire):
            return questionnaire.title?.value?.string
        case .healthDataCollection:
            return nil
        }
    }
}



extension Swift.Duration {
    /// The duration's total length, in milliseconds.
    public var totalMilliseconds: Double {
        Double(components.seconds) * 1000 + Double(components.attoseconds) * 1e-15
    }
    
    /// The duration's total length, in seconds.
    public var totalSeconds: Double {
        totalMilliseconds / 1000
    }

}
