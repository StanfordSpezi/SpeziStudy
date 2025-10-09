//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import ModelsR4
import SpeziLocalization
@_spi(APISupport) import SpeziStudyDefinition


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
            // TODO add a failureReason/Explanation here?
        )
        
        /// The questionnaire as a whole, or one of its items, contains a field with an invalid value.
        ///
        /// - parameter fileRef: The questionnaire in question.
        /// - parameter itemPath: The path of the item this issue relates to, within the questionnaire. `[]` if a questionnaire-level field is invalid.
        /// - parameter fieldName: The name of the field im question.
        /// - parameter fieldValue: The value of the field in question.
        /// - parameter failureReason: An explanation of why exactly this field's value is invalid.
        case invalidField( // swiftlint:disable:this enum_case_associated_values_count
            fileRef: StudyBundle.LocalizedFileReference,
            path: Path,
            fieldValue: Value?,
            failureReason: String
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
        
        public struct Path: Hashable, CustomStringConvertible, ExpressibleByArrayLiteral, Sendable {
            public enum Element: Hashable, Sendable {
                /// The element is referring to the `QuestionnaireItem` at the specific index
                case item(idx: Int)
                /// The element is referring to the field with the specified name.
                case field(name: String)
            }
            
            private let elements: [Element]
            
            public var description: String {
                if elements.isEmpty {
                    "root"
                } else {
                    elements
                        .lazy
                        .map { element in
                            switch element {
                            case .item(let idx):
                                "items[\(idx)]"
                            case .field(let name):
                                name
                            }
                        }
                        .joined(separator: ".")
                }
            }
            
            init(_ seq: some Sequence<Element>) {
                elements = Array(seq)
            }
            
            public init(arrayLiteral elements: Element...) {
                self.init(elements)
            }
            
            static var root: Self { .init(EmptyCollection()) }
            
            func appending(_ element: Element) -> Self {
                .init(elements + CollectionOfOne(element))
            }
            
            func appending(_ other: Path) -> Self {
                .init(elements + other.elements)
            }
        }
        
        public struct Value: Hashable, Sendable { // swiftlint:disable:this nesting
            private let type: Any.Type
            let value: any Hashable & Sendable
            
            init?(_ value: (some Hashable & Sendable)?) {
                if let value {
                    self.type = Swift.type(of: value)
                    self.value = value
                } else {
                    return nil
                }
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
    func validateQuestionnaires() throws -> [BundleValidationIssue.QuestionnaireIssue] { // swiftlint:disable:this function_body_length
        let questionnaireFileRefs = { () -> Set<StudyBundle.FileReference> in
            // we look at all questionnaires that are explicitly referenced from study components ...
            var fileRefs: Set<FileReference> = self.studyDefinition.components.compactMapIntoSet {
                switch $0 {
                case .questionnaire(let component):
                    component.fileRef
                default:
                    nil
                }
            }
            // ... and also at all those that are not, but still are included with the study bundle.
            let questionnairesUrl = Self.folderUrl(for: .questionnaire, relativeTo: self.bundleUrl).resolvingSymlinksInPath().absoluteURL
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
        let fileManager = FileManager.default
        var issues: [BundleValidationIssue.QuestionnaireIssue] = []
        for fileRef in questionnaireFileRefs.sorted(using: [KeyPathComparator(\.category.rawValue), KeyPathComparator(\.filename)]) {
            /// all files for this fileRef's category
            let urls = (try? fileManager.contentsOfDirectory(
                at: Self.folderUrl(for: fileRef.category, relativeTo: bundleUrl),
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
                at: .init(fileRef: fileRef, localization: base.fileRef.localization),
                issues: &issues
            )
            
            for other in questionnaires.filter({ $0.fileRef != base.fileRef }) {
                check(
                    other.questionnaire,
                    at: .init(fileRef: fileRef, localization: other.fileRef.localization),
                    issues: &issues
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
                    pathSoFar: [],
                    issues: &issues
                )
            }
        }
        return issues
    }
    
    
    /// Validates a single (localized) variant of a questionnaire, checking that all expected fields and values exist, and are valid.
    private func check( // swiftlint:disable:this function_body_length
        _ questionnaire: Questionnaire,
        at fileRef: LocalizedFileReference,
        issues: inout [BundleValidationIssue.QuestionnaireIssue]
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
            checkItems(of: questionnaire, at: fileRef, pathSoFar: [], issues: &issues)
        }
    }
    
    
    /// Validates the items of a single questionnaire, checking that all required items we'd expect are present.
    private func checkItems(
        of itemsContainer: some QuestionnaireItemsContainer,
        at fileRef: LocalizedFileReference,
        pathSoFar: BundleValidationIssue.QuestionnaireIssue.Path,
        issues: inout [BundleValidationIssue.QuestionnaireIssue]
    ) {
        for (itemIdx, item) in (itemsContainer.item ?? []).enumerated() {
            let pathSoFar = pathSoFar.appending(.item(idx: itemIdx))
            func checkHasValue(_ keyPath: KeyPath<QuestionnaireItem, (some Any)?>, _ name: String, skipIf shouldSkip: Bool = false) {
                if item[keyPath: keyPath] == nil && !shouldSkip {
                    issues.append(.missingField(
                        fileRef: fileRef,
                        path: pathSoFar.appending(.field(name: name))
                    ))
                }
            }
            checkHasValue(\.linkId.value, "linkId")
            checkHasValue(\.text?.value, "text", skipIf: item.type == .group)
            switch item.type.value {
            case .choice:
                guard let options = item.answerOption, let firstOption = options.first else {
                    // the item has type "choice", but does not contain any options the user could choose from.
                    issues.append(.missingField(
                        fileRef: fileRef,
                        path: pathSoFar.appending(.field(name: "answerOption"))
                    ))
                    break
                }
                for (optionIdx, option) in options.enumerated() {
                    let pathSoFar = pathSoFar.appending([.field(name: "answerOption"), .item(idx: optionIdx)])
                    switch option.value {
                    case .coding(let coding):
                        let pathSoFar = pathSoFar.appending(.field(name: "valueCoding"))
                        if let system = coding.system?.value?.url {
//                                if system != firstOption.value.coding?.system?.value?.url {
//                                    issues.append(.invalidField(
//                                        fileRef: fileRef,
//                                        path: pathSoFar.appending(.field(name: "system")),
//                                        fieldValue: .init(system),
//                                        failureReason: "AnswerOption 'system' value differs from other "
//                                    ))
//                                }
                        } else {
                            issues.append(.missingField(fileRef: fileRef, path: pathSoFar.appending(.field(name: "system"))))
                        }
                        if let id = coding.id?.value?.string {
//                                acc.ids.insert(id)
                        } else {
                            issues.append(.missingField(fileRef: fileRef, path: pathSoFar.appending(.field(name: "id"))))
                        }
                    case .date, .integer, .string, .time, .reference:
                        issues.append(.invalidField(
                            fileRef: fileRef,
                            path: pathSoFar,
                            fieldValue: nil,
                            failureReason: "Expected 'valueCoding' answer option; got smth else."
                        ))
                    }
                }
            default:
                break
            }
            checkItems(of: item, at: fileRef, pathSoFar: pathSoFar, issues: &issues)
        }
    }
    
    
    /// Recursively validates the items of two questionnaires against each other.
    ///
    /// This function mainly just compares that the two questionnaires contain equal items, w.r.t. some non-localized fields.
    /// It does not check for existence of required, possibly localized items; use ``checkItems(of:pathSoFar:)`` for that.
    private func checkItems(
        of other: (some QuestionnaireItemsContainer)?,
        at otherFileRef: LocalizedFileReference,
        against base: (some QuestionnaireItemsContainer)?,
        at baseFileRef: LocalizedFileReference,
        pathSoFar: BundleValidationIssue.QuestionnaireIssue.Path,
        issues: inout [BundleValidationIssue.QuestionnaireIssue]
    ) {
        let baseItems = base?.item ?? []
        let otherItems = other?.item ?? []
        guard baseItems.count == otherItems.count else {
            issues.append(.mismatchingFieldValues(
                baseFileRef: baseFileRef,
                localizedFileRef: otherFileRef,
                path: pathSoFar.appending([.field(name: "item"), .field(name: "length")]),
                baseValue: .init(baseItems.count),
                localizedValue: .init(otherItems.count)
            ))
            return
        }
        for (itemIdx, (baseItem, otherItem)) in zip(baseItems, otherItems).enumerated() {
            let pathSoFar = pathSoFar.appending(.item(idx: itemIdx))
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
                path: BundleValidationIssue.QuestionnaireIssue.Path = pathSoFar
            ) -> Bool {
                let baseValue = baseItem[keyPath: keyPath]
                let itemValue = otherItem[keyPath: keyPath]
                if baseValue != itemValue {
                    issues.append(.mismatchingFieldValues(
                        baseFileRef: baseFileRef,
                        localizedFileRef: otherFileRef,
                        path: path.appending(.field(name: name)),
                        baseValue: .init(baseValue),
                        localizedValue: .init(itemValue)
                    ))
                    return false
                } else {
                    return true
                }
            }
            checkEqual(\.linkId.value, "linkId")
            checkEqual(\.type.value, "type")
            checkEqual(\.required?.value, "required")
            checkEqual(\.repeats?.value, "repeats")
            checkEqual(\.readOnly?.value, "readOnly")
//            checkEqual(\.initial?., "readOnly")
//            checkEqual(\.enabledWhen?., "readOnly")
            switch baseItem.type.value {
            case .choice:
                // we don't need to check for non-emptiness here; that already happened in the other function.
                let baseItemOptions = baseItem.answerOption ?? []
                let otherItemOptions = otherItem.answerOption ?? []
                guard baseItemOptions.count == otherItemOptions.count else {
                    issues.append(.mismatchingFieldValues(
                        baseFileRef: baseFileRef,
                        localizedFileRef: otherFileRef,
                        path: pathSoFar.appending([.field(name: "answerOption"), .field(name: "length")]),
                        baseValue: .init(baseItemOptions.count),
                        localizedValue: .init(otherItemOptions.count)
                    ))
                    break
                }
                for (optionIdx, (baseOption, otherOption)) in zip(baseItemOptions, otherItemOptions).enumerated() {
                    let pathSoFar = pathSoFar.appending([.field(name: "answerOption"), .item(idx: optionIdx)])
                    switch (baseOption.value, otherOption.value) {
                    case let (.coding(baseCoding), .coding(otherCoding)):
                        let pathSoFar = pathSoFar.appending(.field(name: "valueCoding"))
                        checkEqual(\.answerOption?[optionIdx].value.coding?.system?.value?.url, "system", path: pathSoFar)
                        checkEqual(\.answerOption?[optionIdx].value.coding?.id?.value?.string, "id", path: pathSoFar)
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
                    // TODO record issue!
                    break
                }
                func imp(_ keyPath: KeyPath<Coding, some Hashable & Sendable>, _ name: String) {
                    let baseVal = baseDef[keyPath: keyPath]
                    let otherVal = otherDef[keyPath: keyPath]
                    if baseVal != otherVal {
                        issues.append(.mismatchingFieldValues(
                            baseFileRef: baseFileRef,
                            localizedFileRef: otherFileRef,
                            path: pathSoFar.appending([.field(name: "extension"), .field(name: "unit"), .field(name: name)]),
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
                guard checkEqual(\.enableWhen?.count, "length", path: pathSoFar.appending(.field(name: "enableWhen"))) else {
//                guard baseConditions.count == otherConditions.count else {
//                    issues.append(.mismatchingFieldValues(
//                        baseFileRef: baseFileRef,
//                        localizedFileRef: otherFileRef,
//                        path: pathSoFar.appending([.field(name: "enableWhen"), .field(name: "length")]),
//                        baseValue: .init(baseConditions.count),
//                        localizedValue: .init(otherConditions.count)
//                    ))
                    break
                }
                for (condIdx, (baseCond, otherCond)) in zip(baseConditions, otherConditions).enumerated() {
                    let pathSoFar = pathSoFar.appending([.field(name: "enableWhen"), .item(idx: condIdx)])
                    checkEqual(\.enableWhen![condIdx].question.value, "question", path: pathSoFar)
                    checkEqual(\.enableWhen![condIdx].operator.value, "operator", path: pathSoFar)
//                    checkEqual(\.enableWhen![condIdx].answer, "answer")
                    func imp<T: Hashable & Sendable>(_ answerFieldName: String, baseVal: T?, otherVal: T?) {
                        if baseVal != otherVal {
                            issues.append(.mismatchingFieldValues(
                                baseFileRef: baseFileRef,
                                localizedFileRef: otherFileRef,
                                path: pathSoFar.appending([.field(name: "answer"), .field(name: answerFieldName)]),
                                baseValue: .init(baseVal),
                                localizedValue: .init(otherVal)
                            ))
                        }
                    }
                    switch (baseCond.answer, otherCond.answer) {
                    case let (.boolean(lhsVal), .boolean(rhsVal)):
                        imp("boolean", baseVal: lhsVal.value, otherVal: rhsVal.value)
                    case let (.coding(lhsVal), .coding(rhsVal)):
                        imp("coding.system", baseVal: lhsVal.system?.value, otherVal: rhsVal.system?.value)
                        imp("coding.id", baseVal: lhsVal.id?.value, otherVal: rhsVal.id?.value)
                    case let (.date(lhsVal), .date(rhsVal)):
                        imp("date", baseVal: lhsVal.value, otherVal: rhsVal.value)
                    case let (.dateTime(lhsVal), .dateTime(rhsVal)):
                        imp("dateTime", baseVal: lhsVal.value, otherVal: rhsVal.value)
                    case let (.decimal(lhsVal), .decimal(rhsVal)):
                        imp("decimal", baseVal: lhsVal.value, otherVal: rhsVal.value)
                    case let (.integer(lhsVal), .integer(rhsVal)):
                        imp("integer", baseVal: lhsVal.value, otherVal: rhsVal.value)
                    case let (.quantity(lhsVal), .quantity(rhsVal)):
                        imp("quantity.system", baseVal: lhsVal.system?.value, otherVal: rhsVal.system?.value)
                        imp("quantity.code", baseVal: lhsVal.code?.value, otherVal: rhsVal.code?.value)
                        imp("quantity.unit", baseVal: lhsVal.unit?.value, otherVal: rhsVal.unit?.value)
                        imp("quantity.value", baseVal: lhsVal.value?.value, otherVal: rhsVal.value?.value)
                    case let (.reference(lhsVal), .reference(rhsVal)):
                        imp("reference.type", baseVal: lhsVal.type?.value, otherVal: rhsVal.type?.value)
                        imp("reference.reference", baseVal: lhsVal.reference?.value, otherVal: rhsVal.reference?.value)
                    case let (.string(lhsVal), .string(rhsVal)):
                        imp("strig", baseVal: lhsVal.value, otherVal: rhsVal.value)
                    case let (.time(lhsVal), .time(rhsVal)):
                        imp("time", baseVal: lhsVal.value, otherVal: rhsVal.value)
                    default:
                        issues.append(.mismatchingFieldValues(
                            baseFileRef: baseFileRef,
                            localizedFileRef: otherFileRef,
                            path: pathSoFar.appending(.field(name: "answer")),
                            baseValue: nil,
                            localizedValue: nil
                        ))
                    }
//                    baseCond.question
//                    baseCond.operator
//                    baseCond.answer
                }
            }
            
            // descend into any potential nested child items
            checkItems(
                of: otherItem,
                at: otherFileRef,
                against: baseItem,
                at: baseFileRef,
                pathSoFar: pathSoFar,
                issues: &issues
            )
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
    var item: [QuestionnaireItem]? { get }
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

