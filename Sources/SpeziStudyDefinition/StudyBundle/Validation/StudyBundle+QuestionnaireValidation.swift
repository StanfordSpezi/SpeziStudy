//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_length file_types_order

import Foundation
import ModelsR4
import SpeziFoundation
import SpeziLocalization


extension StudyBundle.BundleValidationIssue {
    public enum QuestionnaireIssue: Hashable, Sendable {
        /// The questionnaire as a whole, or one of its items, it missing a field.
        ///
        /// - parameter fileRef: The questionnaire in question.
        /// - parameter itemPath: The path of the item this issue relates to, within the questionnaire. `[]` if a questionnaire-level field is missing.
        /// - parameter fieldName: The name of the missing field.
        case missingField(
            fileRef: StudyBundle.LocalizedFileReference,
            path: Path
        )
        
        /// The questionnaire as a whole, or one of its items, contains a field with an invalid value.
        ///
        /// - parameter fileRef: The questionnaire in question.
        /// - parameter itemPath: The path of the item this issue relates to, within the questionnaire. `[]` if a questionnaire-level field is invalid.
        /// - parameter fieldName: The name of the field im question.
        /// - parameter fieldValue: The value of the field in question.
        /// - parameter failureReason: An explanation of why exactly this field's value is invalid.
        case invalidField(
            fileRef: StudyBundle.LocalizedFileReference,
            path: Path,
            fieldValue: Value?,
            failureReason: String
        )
        
        /// A two fields within a single localization of a questionnaire have conflicting values.
        ///
        /// - parameter fileRef: The questionnaire with the issue.
        /// - parameter fstPath: The ``Path`` of the first value in this conflict.
        /// - parameter fstValue: The first value in this conflict.
        /// - parameter sndPath: The ``Path`` of the second value in this conflict.
        /// - parameter sndValue: The second value in this conflict.
        case conflictingFieldValues( // swiftlint:disable:this enum_case_associated_values_count
            fileRef: StudyBundle.LocalizedFileReference,
            fstPath: Path,
            fstValue: Value?,
            sndPath: Path,
            sndValue: Value?,
            comment: String?
        )
        
        /// A field in a localized version of a questionnaire has a value that doesn't match the base localization.
        ///
        /// - parameter baseFileRef: The base localization of the questionnaire.
        ///     This is the version we use as the "ground truth", i.e., the version all other localizations' should match. Typically the `en-US` localization.
        /// - parameter localizedFileRef: The localization this issue relates to.
        /// - parameter itemPath: The path of the item this issue relates to, within the questionnaire. `[]` if a questionnaire-level field is missing.
        /// - parameter fieldName: The name of the missing field.
        /// - parameter baseValue: The value of the field as present in the base localization. This is the "expected" value that should also be present in the `localizedFileRef`.
        /// - parameter localizedValue: The actual value of the field in the `localizedFileRef`.
        case mismatchingFieldValues( // swiftlint:disable:this enum_case_associated_values_count
            baseFileRef: StudyBundle.LocalizedFileReference,
            localizedFileRef: StudyBundle.LocalizedFileReference,
            path: Path,
            baseValue: Value?,
            localizedValue: Value?
        )
        
        /// The language in the questionnaire's metadata does not match the language in the filename's localization component.
        case languageDiffersFromFilenameLocalization(
            fileRef: StudyBundle.LocalizedFileReference,
            questionnaireLanguage: String
        )
        
        @dynamicMemberLookup
        public struct Path: Hashable, CustomStringConvertible, ExpressibleByArrayLiteral, Sendable {
            public enum Component: Hashable, Sendable { // swiftlint:disable:this nesting
                /// The element is referring to the field with the specified name.
                case field(name: String)
                /// The element is referring to the `QuestionnaireItem` at the specific index
                case `subscript`(idx: Int)
            }
            
            // https://github.com/swiftlang/swift/issues/84808
            static var root: Self { .init([]) }
            
            let components: [Component]
            
            public var description: String {
                if components.isEmpty {
                    "root"
                } else {
                    components.reduce(into: "") { path, component in
                        switch component {
                        case .field(let name):
                            if !path.isEmpty {
                                path.append(".")
                            }
                            path.append(name)
                        case .subscript(let idx):
                            path.append("[\(idx)]")
                        }
                    }
                }
            }
            
            init(_ seq: some Sequence<Component>) {
                components = Array(seq)
            }
            public init(arrayLiteral components: Component...) {
                self.init(components)
            }
            
            /// Creates a new ``Path`` that accesses the root-level field `name`.
            static subscript(dynamicMember name: String) -> Self {
                .root[dynamicMember: name]
            }
            /// Creates a new ``Path`` by appending a field access component.
            subscript(dynamicMember name: String) -> Self {
                Self(components + CollectionOfOne(.field(name: name)))
            }
            /// Creates a new ``Path`` by appending an `Int`-based indexing subscript component.
            subscript(idx: Int) -> Self {
                Self(components + CollectionOfOne(.subscript(idx: idx)))
            }
            /// Creates a new ``Path`` by appending a field access component.
            subscript(name: String) -> Self {
                Self(components + CollectionOfOne(.field(name: name)))
            }
        }
        
        /// A Hashable wrapper around some value we found in a questionnaire and want to report/dispay to the user.
        ///
        /// - Note: This type is `Sendable`. We canot express this via the type system (`Sendable` is a marker protocol, so we can't dynamically check for conformance at runtime),
        ///     but all non-private initializers require their input be `Sendable`, and we only descend into types where we can safely assume that if the type as a whole is `Sendable`,
        ///     any contained values will be as well (i.e., `Optional` and `FHIRPrimitive`).
        public struct Value: Hashable, @unchecked Sendable {
            private let type: Any.Type
            let value: any Hashable
            
            init?(_ value: (any Hashable & Sendable)?) {
                self.init(value: value)
            }
            
            init?(_ value: FHIRPrimitive<some Hashable & Sendable>?) {
                self.init(value?.value)
            }
            
            /// - precondition: `O` must be `Hashable`
            private init?<O: AnyOptional>(value: O) {
                if let value = value.unwrappedOptional {
                    if let value = value as? any AnyOptional {
                        self.init(value: value)
                    } else {
                        // SAFETY: the force-cast here is ok, bc we only call this initializer from the other one,
                        // which has a `Hashable & Sendable` requirement, and we only descend into types which propagate their Hashable conformance.
                        self.init(value: value as! any Hashable) // swiftlint:disable:this force_cast
                    }
                } else {
                    return nil
                }
            }
            
            private init?(value: any Hashable) {
                switch value {
                case let value as FHIRString:
                    self.init(value: value.string)
                case let value as FHIRInteger:
                    self.init(value: value.integer)
                case let value as FHIRDecimal:
                    self.init(value: value.decimal)
                case let value as FHIRPositiveInteger:
                    self.init(value: value.integer)
                case let value as FHIRUnsignedInteger:
                    self.init(value: value.integer)
                case let value as FHIRDate:
                    if let date = try? value.asNSDate() {
                        self.init(value: date)
                    } else {
                        return nil
                    }
                case let value as FHIRURI:
                    self.init(value: value.url)
                default:
                    self.init(fullyUnwrapped: value)
                }
            }
            
            private init(fullyUnwrapped value: any Hashable) {
                self.type = Swift.type(of: value)
                self.value = value
            }
            
            public static func == (lhs: Self, rhs: Self) -> Bool {
                lhs.value.isEqual(rhs.value) && lhs.type == rhs.type
            }
            public func hash(into hasher: inout Hasher) {
                hasher.combine(ObjectIdentifier(type))
                value.hash(into: &hasher)
            }
        }
    }
}


extension StudyBundle {
    func validateQuestionnaires() throws -> [BundleValidationIssue.QuestionnaireIssue] {
        try QuestionnaireValidator(studyBundle: self).run()
    }
}


private struct QuestionnaireValidator: ~Copyable { // swiftlint:disable:this type_body_length
    typealias Issue = StudyBundle.BundleValidationIssue.QuestionnaireIssue
    typealias FileReference = StudyBundle.FileReference
    typealias LocalizedFileReference = StudyBundle.LocalizedFileReference
    typealias Path = Issue.Path
    
    private struct SeenChoiceOption: Hashable {
        let fileRef: LocalizedFileReference
        let path: Path
        let system: URL
        let code: String
        let title: String
    }
    
    private let studyBundle: StudyBundle
    private let fileRefs: [FileReference]
    private var issues: [Issue] = []
    private var allChoiceOptions: [SeenChoiceOption] = []
    
    
    init(studyBundle: StudyBundle) {
        self.studyBundle = studyBundle
        let fileRefs = { () -> Set<FileReference> in
            // we look at all questionnaires that are explicitly referenced from study components ...
            var fileRefs: Set<FileReference> = studyBundle.studyDefinition.components.compactMapIntoSet {
                switch $0 {
                case .questionnaire(let component):
                    component.fileRef
                default:
                    nil
                }
            }
            // ... and also at all those that are not, but still are included with the study bundle.
            let questionnairesUrl = StudyBundle
                .folderUrl(for: .questionnaire, relativeTo: studyBundle.bundleUrl)
                .resolvingSymlinksInPath()
                .absoluteURL
            guard let enumerator = FileManager.default.enumerator(at: questionnairesUrl, includingPropertiesForKeys: nil) else {
                return fileRefs
            }
            for url in enumerator.lazy.compactMap({ (($0 as? NSURL)?.path).map { URL(filePath: $0) } }) {
                guard let unlocalizedUrl = LocalizedFileResolution.parse(url.absoluteURL)?.unlocalizedUrl.standardized,
                      unlocalizedUrl.pathExtension == "json" else {
                    continue
                }
                // we can only call -resolvingSymlinksInPath on a URL that actually points to a valid file system object,
                // so we need to do a little dance here where we remove the last component (to make the URL point to the containing folder),
                // and then re-add it after having normalized the path.
                let pathComponents = unlocalizedUrl
                    .deletingLastPathComponent()
                    .resolvingSymlinksInPath()
                    .appending(component: unlocalizedUrl.deletingPathExtension().lastPathComponent)
                    .pathComponents
                fileRefs.insert(.init(
                    category: .questionnaire,
                    filename: pathComponents.dropFirst(questionnairesUrl.pathComponents.count).joined(separator: "/"),
                    fileExtension: "json"
                ))
            }
            return fileRefs
        }()
        self.fileRefs = fileRefs.sorted(using: [KeyPathComparator(\.category.rawValue), KeyPathComparator(\.filename)])
    }
    
    
    consuming func run() throws -> [Issue] {
        try validateQuestionnaires()
        performPostProcessing()
        return issues
    }
    
    
    private mutating func performPostProcessing() {
        // create issues for duplicate/conflicting single/multiple choice options
        do {
            struct WithoutTitle: Hashable {
                let localization: LocalizationKey
                let system: URL
                let code: String
            }
            var reported = Set<SeenChoiceOption>()
            for option in allChoiceOptions {
                let conflicting = allChoiceOptions.filter { other in
                    !reported.contains(other)
                        && other.fileRef.localization == option.fileRef.localization
                        && other.system == option.system
                        && other.code == option.code
                        && other.title != option.title
                }
                for other in conflicting where !reported.contains(other) {
                    // found 2 valueCoding SCMC options (with same localization & system & code) but different titles.
                    issues.append(.conflictingFieldValues(
                        fileRef: option.fileRef,
                        fstPath: option.path.display,
                        fstValue: .init(option.title),
                        sndPath: other.path.display,
                        sndValue: .init(other.title),
                        comment: "Both options have code '\(option.code)' in system '\(option.system)', but they have different titles."
                    ))
                    reported.insert(option)
                    reported.insert(other)
                }
            }
        }
    }
    
    
    private mutating func validateQuestionnaires() throws {
        let fileManager = FileManager.default
        for fileRef in fileRefs {
            /// all files for this fileRef's category
            let urls = (try? fileManager.contentsOfDirectory(
                at: StudyBundle.folderUrl(for: fileRef.category, relativeTo: studyBundle.bundleUrl),
                includingPropertiesForKeys: nil
            )) ?? []
            let candidates = LocalizedFileResolution.selectCandidatesIgnoringLocalization(
                matching: LocalizedFileResource(fileRef),
                from: urls
            )
            let questionnaires = try candidates.map {
                (questionnaire: try JSONDecoder().decode(Questionnaire.self, from: try Data(contentsOf: $0.url)), fileRef: $0)
            }
            
            let base = questionnaires.first { $0.0.language == "en-US" || $0.fileRef.localization == .enUS }
                ?? questionnaires.first { $0.0.language == "en" || $0.fileRef.localization.language.isEquivalent(to: .init(identifier: "en")) }
                ?? questionnaires.first! // swiftlint:disable:this force_unwrapping - SAFETY: we have checked above that this is non-empty
            
            check(
                base.questionnaire,
                at: .init(fileRef: fileRef, localization: base.fileRef.localization)
            )
            
            for other in questionnaires.filter({ $0.fileRef != base.fileRef }) {
                check(
                    other.questionnaire,
                    at: .init(fileRef: fileRef, localization: other.fileRef.localization)
                )
                if base.questionnaire.id?.value?.string != other.questionnaire.id?.value?.string {
                    issues.append(.mismatchingFieldValues(
                        baseFileRef: .init(fileRef: fileRef, localization: base.fileRef.localization),
                        localizedFileRef: .init(fileRef: fileRef, localization: other.fileRef.localization),
                        path: [.field(name: "id")],
                        baseValue: .init(base.questionnaire.id?.value?.string),
                        localizedValue: .init(other.questionnaire.id?.value?.string)
                    ))
                }
                checkItems(
                    of: other.questionnaire,
                    at: .init(fileRef: fileRef, localization: other.fileRef.localization),
                    against: base.questionnaire,
                    at: .init(fileRef: fileRef, localization: base.fileRef.localization),
                    path: []
                )
            }
        }
    }
    
    
    /// Validates a single (localized) variant of a questionnaire, checking that all expected fields and values exist, and are valid.
    private mutating func check(
        _ questionnaire: Questionnaire,
        at fileRef: LocalizedFileReference
    ) {
        if questionnaire.id?.value == nil {
            issues.append(.missingField(fileRef: fileRef, path: [.field(name: "id")]))
        }
        if let questionnaireLangRaw = questionnaire.language?.value?.string, !questionnaireLangRaw.isEmpty {
            if let questionnaireKey = LocalizationKey(questionnaireLangRaw) {
                let fileRefKey = fileRef.localization
                if questionnaireKey != fileRefKey {
                    issues.append(.languageDiffersFromFilenameLocalization(
                        fileRef: fileRef,
                        questionnaireLanguage: questionnaireKey.description
                    ))
                }
            } else {
                // the questionnaire does have a `language` value, but we were unable to parse it into a `LocalizationKey`.
                issues.append(.invalidField(
                    fileRef: fileRef,
                    path: [.field(name: "language")],
                    fieldValue: .init(questionnaireLangRaw),
                    failureReason: "failed to parse into a `LocalizationKey`"
                ))
            }
        } else {
            issues.append(.missingField(fileRef: fileRef, path: [.field(name: "language")]))
        }
        if questionnaire.title?.value == nil {
            issues.append(.missingField(fileRef: fileRef, path: [.field(name: "title")]))
        }
        
        if (questionnaire.item ?? []).isEmpty {
            issues.append(.missingField(fileRef: fileRef, path: [.field(name: "item")]))
            return
        } else {
            checkItems(of: questionnaire, at: fileRef, path: [])
        }
    }
    
    
    /// Validates the items of a single questionnaire, checking that all required items we'd expect are present.
    ///
    /// - parameter path: `Path` of the `itemContainer`
    private mutating func checkItems(
        of itemsContainer: some QuestionnaireItemsContainer,
        at fileRef: LocalizedFileReference,
        path: Path
    ) {
        for (itemIdx, item) in (itemsContainer.item ?? []).enumerated() {
            let path = path.item[itemIdx]
            func checkHasValue(_ keyPath: KeyPath<QuestionnaireItem, (some Any)?>, _ name: String) {
                if item[keyPath: keyPath] == nil {
                    issues.append(.missingField(
                        fileRef: fileRef,
                        path: path[name]
                    ))
                }
            }
            checkHasValue(\.linkId.value, "linkId")
            if item.type != .group {
                checkHasValue(\.text?.value, "text")
            }
            switch item.type.value {
            case .choice:
                guard let options = item.answerOption else {
                    // the item has type "choice", but does not contain any options the user could choose from.
                    issues.append(.missingField(
                        fileRef: fileRef,
                        path: path.answerOption
                    ))
                    break
                }
                for (optionIdx, option) in options.enumerated() {
                    let path = path.answerOption[optionIdx]
                    processChoiceOption(option, at: path, for: item, at: fileRef)
                }
            default:
                break
            }
            checkItems(of: item, at: fileRef, path: path)
        }
    }
    
    
    /// Recursively validates the items of two questionnaires against each other.
    ///
    /// This function mainly just compares that the two questionnaires contain equal items, w.r.t. some non-localized fields.
    /// It does not check for existence of required, possibly localized items; use ``checkItems(of:at:path:)`` for that.
    ///
    /// - parameter path: The `Path` of the item containers.
    private mutating func checkItems( // swiftlint:disable:this function_body_length cyclomatic_complexity
        of other: (some QuestionnaireItemsContainer)?,
        at otherFileRef: LocalizedFileReference,
        against base: (some QuestionnaireItemsContainer)?,
        at baseFileRef: LocalizedFileReference,
        path: Path
    ) {
        let baseItems = base?.item ?? []
        let otherItems = other?.item ?? []
        guard baseItems.count == otherItems.count else {
            issues.append(.mismatchingFieldValues(
                baseFileRef: baseFileRef,
                localizedFileRef: otherFileRef,
                path: path.item.length,
                baseValue: .init(baseItems.count),
                localizedValue: .init(otherItems.count)
            ))
            return
        }
        for (itemIdx, (baseItem, otherItem)) in zip(baseItems, otherItems).enumerated() {
            let path = path.item[itemIdx]
            /// checks if the two items have an equal value at the specified key path
            /// - parameter keyPath: `KeyPath` of the value to compare.
            /// - parameter name: name of the property being compared
            /// - parameter path: the path within the questionnaire, where the field is localed.
            ///     Note that this should **not** point to the field directly, but rather to the node which contains the field!
            /// - returns: A boolean value indicating whether the check succeeded, i.e. whether the two values being compared were equal.
            @discardableResult
            func checkEqual(
                _ keyPath: KeyPath<QuestionnaireItem, (some Hashable & Sendable)>,
                _ name: String,
                path: Path = path
            ) -> Bool {
                let baseValue = baseItem[keyPath: keyPath]
                let itemValue = otherItem[keyPath: keyPath]
                if baseValue == itemValue {
                    return true
                } else {
                    issues.append(.mismatchingFieldValues(
                        baseFileRef: baseFileRef,
                        localizedFileRef: otherFileRef,
                        path: path[name],
                        baseValue: .init(baseValue),
                        localizedValue: .init(itemValue)
                    ))
                    return false
                }
            }
            checkEqual(\.linkId.value, "linkId")
            checkEqual(\.type.value, "type")
            checkEqual(\.required?.value, "required")
            checkEqual(\.repeats?.value, "repeats")
            checkEqual(\.readOnly?.value, "readOnly")
            switch baseItem.type.value {
            case .choice:
                // we don't need to check for non-emptiness here; that already happened in the other function.
                let baseItemOptions = baseItem.answerOption ?? []
                let otherItemOptions = otherItem.answerOption ?? []
                guard baseItemOptions.count == otherItemOptions.count else {
                    issues.append(.mismatchingFieldValues(
                        baseFileRef: baseFileRef,
                        localizedFileRef: otherFileRef,
                        path: path.answerOption.length,
                        baseValue: .init(baseItemOptions.count),
                        localizedValue: .init(otherItemOptions.count)
                    ))
                    break
                }
                for (optionIdx, (baseOption, otherOption)) in zip(baseItemOptions, otherItemOptions).enumerated() {
                    let path = path.answerOption[optionIdx]
                    switch (baseOption.value, otherOption.value) {
                    case (.coding, .coding):
                        let path = path.valueCoding
                        checkEqual(\.answerOption?[optionIdx].value.coding?.system?.value?.url, "system", path: path)
                        checkEqual(\.answerOption?[optionIdx].value.coding?.id?.value?.string, "id", path: path)
                    default:
                        break
                    }
                }
            case .quantity:
                // https://hl7.org/fhir/R4/codesystem-item-type.html#item-type-quantity
                let extensionUrl = "http://hl7.org/fhir/StructureDefinition/questionnaire-unit"
                let baseExt = baseItem.extensions(for: extensionUrl)
                let otherExt = otherItem.extensions(for: extensionUrl)
                guard baseExt.count == 1, let baseDef = baseExt.first?.value?.coding,
                      otherExt.count == 1, let otherDef = otherExt.first?.value?.coding else {
                    // Q: record issue?
                    break
                }
                func imp(_ keyPath: KeyPath<Coding, some Hashable & Sendable>, _ name: String) {
                    let baseVal = baseDef[keyPath: keyPath]
                    let otherVal = otherDef[keyPath: keyPath]
                    if baseVal != otherVal {
                        issues.append(.mismatchingFieldValues(
                            baseFileRef: baseFileRef,
                            localizedFileRef: otherFileRef,
                            path: path.extension.unit[name],
                            baseValue: .init(baseVal),
                            localizedValue: .init(otherVal)
                        ))
                    }
                }
                imp(\.system?.value?.url, "system")
                imp(\.code?.value?.string, "code")
            default:
                break
            }
            
            // check branching conditions
            if !((baseItem.enableWhen ?? []).isEmpty && (otherItem.enableWhen ?? []).isEmpty) {
                checkEqual(\.enableBehavior?.value, "enableBehavior")
            }
            switch (baseItem.enableWhen ?? [], otherItem.enableWhen ?? []) {
            case ([], []):
                break
            case let (baseConditions, otherConditions):
                guard checkEqual(\.enableWhen?.count, "length", path: path.enableWhen) else {
                    break
                }
                for (condIdx, (baseCond, otherCond)) in zip(baseConditions, otherConditions).enumerated() {
                    let path = path.enableWhen[condIdx]
                    checkEqual(\.enableWhen![condIdx].question.value, "question", path: path)
                    checkEqual(\.enableWhen![condIdx].operator.value, "operator", path: path)
                    func imp<T: Hashable & Sendable>(baseVal: T?, otherVal: T?, path: Path) {
                        if baseVal != otherVal {
                            issues.append(.mismatchingFieldValues(
                                baseFileRef: baseFileRef,
                                localizedFileRef: otherFileRef,
                                path: path,
                                baseValue: .init(baseVal),
                                localizedValue: .init(otherVal)
                            ))
                        }
                    }
                    let answerPath = path.answer
                    switch (baseCond.answer, otherCond.answer) {
                    case let (.boolean(lhsVal), .boolean(rhsVal)):
                        imp(baseVal: lhsVal.value, otherVal: rhsVal.value, path: answerPath.boolean)
                    case let (.coding(lhsVal), .coding(rhsVal)):
                        imp(baseVal: lhsVal.system?.value, otherVal: rhsVal.system?.value, path: answerPath.coding.system)
                        imp(baseVal: lhsVal.code?.value, otherVal: rhsVal.code?.value, path: answerPath.coding.code)
                    case let (.date(lhsVal), .date(rhsVal)):
                        imp(baseVal: lhsVal.value, otherVal: rhsVal.value, path: answerPath.date)
                    case let (.dateTime(lhsVal), .dateTime(rhsVal)):
                        imp(baseVal: lhsVal.value, otherVal: rhsVal.value, path: answerPath.dateTime)
                    case let (.decimal(lhsVal), .decimal(rhsVal)):
                        imp(baseVal: lhsVal.value, otherVal: rhsVal.value, path: answerPath.decimal)
                    case let (.integer(lhsVal), .integer(rhsVal)):
                        imp(baseVal: lhsVal.value, otherVal: rhsVal.value, path: answerPath.integer)
                    case let (.quantity(lhsVal), .quantity(rhsVal)):
                        imp(baseVal: lhsVal.system?.value, otherVal: rhsVal.system?.value, path: answerPath.quantity.system)
                        imp(baseVal: lhsVal.code?.value, otherVal: rhsVal.code?.value, path: answerPath.quantity.code)
                        imp(baseVal: lhsVal.unit?.value, otherVal: rhsVal.unit?.value, path: answerPath.quantity.unit)
                        imp(baseVal: lhsVal.value?.value, otherVal: rhsVal.value?.value, path: answerPath.quantity.value)
                    case let (.reference(lhsVal), .reference(rhsVal)):
                        imp(baseVal: lhsVal.type?.value, otherVal: rhsVal.type?.value, path: answerPath.reference.type)
                        imp(baseVal: lhsVal.reference?.value, otherVal: rhsVal.reference?.value, path: answerPath.reference.reference)
                    case let (.string(lhsVal), .string(rhsVal)):
                        imp(baseVal: lhsVal.value, otherVal: rhsVal.value, path: answerPath.string)
                    case let (.time(lhsVal), .time(rhsVal)):
                        imp(baseVal: lhsVal.value, otherVal: rhsVal.value, path: answerPath.time)
                    default:
                        issues.append(.mismatchingFieldValues(
                            baseFileRef: baseFileRef,
                            localizedFileRef: otherFileRef,
                            path: path.answer,
                            baseValue: nil,
                            localizedValue: nil
                        ))
                    }
                }
            }
            
            // descend into any potential nested child items
            checkItems(
                of: otherItem,
                at: otherFileRef,
                against: baseItem,
                at: baseFileRef,
                path: path
            )
        }
    }
    
    
    private mutating func processChoiceOption(
        _ option: QuestionnaireItemAnswerOption,
        at path: Path,
        for item: QuestionnaireItem,
        at fileRef: LocalizedFileReference
    ) {
        switch option.value {
        case .coding(let coding):
            // Note that we intentionally ignore the `id` field here, and instead use the combination of system and code to establish identity.
            let path = path.valueCoding
            let system = coding.system?.value?.url
            let code = coding.code?.value?.string
            let title = coding.display?.value?.string
            for (value, name) in [(system, "system"), (code, "code"), (title, "title") ] as [((any Equatable)?, String)] {
                if value == nil { // swiftlint:disable:this for_where
                    issues.append(.missingField(fileRef: fileRef, path: path[name]))
                }
            }
            if let system, let code, let title {
                // Note that we don't check for duplicates and create issues directly in here; instead this is a one-time
                // postprocessing step to avoid finding and reporting the same duplicate multiple times.
                allChoiceOptions.append(.init(fileRef: fileRef, path: path, system: system, code: code, title: title))
            }
        case .date, .integer, .time, .string, .reference:
            issues.append(.invalidField(
                fileRef: fileRef,
                path: path.value,
                fieldValue: .init(option.value.kindType),
                failureReason: "Unsupported answer option kind '\(option.value.kindType)'; only 'valueCoding' is currently supported."
            ))
        }
    }
}


// MARK: Helpers

extension QuestionnaireItemType: @retroactive @unchecked Sendable {}
extension EnableWhenBehavior: @retroactive @unchecked Sendable {}
extension QuestionnaireItemOperator: @retroactive @unchecked Sendable {}

extension QuestionnaireItemAnswerOption.ValueX {
    fileprivate var coding: Coding? {
        switch self {
        case .coding(let coding):
            coding
        case .date, .integer, .string, .time, .reference:
            nil
        }
    }
    
    fileprivate var kindType: String {
        switch self {
        case .coding:
            "coding"
        case .date:
            "date"
        case .integer:
            "integer"
        case .reference:
            "reference"
        case .string:
            "string"
        case .time:
            "time"
        }
    }
}


extension Extension.ValueX {
    fileprivate var coding: Coding? {
        switch self {
        case .coding(let coding):
            coding
        default:
            nil
        }
    }
}


private protocol QuestionnaireItemsContainer {
    var item: [QuestionnaireItem]? { get } // swiftlint:disable:this discouraged_optional_collection
}
extension Questionnaire: QuestionnaireItemsContainer {}
extension QuestionnaireItem: QuestionnaireItemsContainer {}


extension Equatable {
    fileprivate func isEqual(_ other: Any) -> Bool {
        if let other = other as? Self {
            self == other
        } else {
            false
        }
    }
}


extension StudyBundle.BundleValidationIssue.QuestionnaireIssue.Path {
}
