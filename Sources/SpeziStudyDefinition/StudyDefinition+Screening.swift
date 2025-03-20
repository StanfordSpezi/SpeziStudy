//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import DequeModule
import Foundation


extension StudyDefinition {
    public struct ParticipationCriteria: StudyDefinitionElement {
        /// A criterion which must be satisfied for a person to be able to participate in a study.
        ///
        /// IDEA might want to add the concept of public/internal criterions (public would be ones which are communicated to the user / the user can know about; internal would be for e.g. inter-study dependencies)
        public indirect enum Criterion: StudyDefinitionElement {
            /// a criterion which evaluates to true if the user is at least of the specified age
            case ageAtLeast(Int)
            /// a criterion which evaluates to true if the user is from the specified region
            case isFromRegion(Locale.Region)
            /// a criterion which evaluates to true if the user speaks the specified language
            case speaksLanguage(Locale.Language)
            /// a criterion which evaluates to true based on a custom condition
            case custom(CustomCriterionKey)
            
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
            
            public struct CustomCriterionKey: Codable, Hashable, Sendable { // swiftlint:disable:this nesting
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
                criterionData = try! JSONEncoder().encode(newValue) // swiftlint:disable:this force_try
            }
            set {
                criterionData = try! JSONEncoder().encode(newValue) // swiftlint:disable:this force_try
            }
            get {
                try! JSONDecoder().decode(Criterion.self, from: criterionData) // swiftlint:disable:this force_try
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


// MARK: Criterion Eval

extension StudyDefinition.ParticipationCriteria.Criterion {
    /// Context against which the ``StudyDefinition/ParticipationCriteria`` are evaluated.
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
    
    
    /// Determine whether the criteria are satisfied.
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
}
