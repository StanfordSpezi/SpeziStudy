//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import ModelsR4
import SpeziFoundation
import SpeziLocalization


extension StudyBundle {
    enum BundleValidationIssue: CustomStringConvertible, Hashable, Sendable {
        case general(GeneralIssue)
        case article(ArticleIssue)
        case questionnaire(QuestionnaireIssue)
        
        enum GeneralIssue: Hashable, Sendable {
            /// The study bundle doesn't contain any files that would match the file reference found in the study definition.
            case noFilesMatchingFileRef(StudyBundle.FileReference)
        }
        
        enum ArticleIssue: Hashable, Sendable {
            case documentMetadataMissingId(LocalizedFileReference)
            case documentMetadataIdMismatchToBase(
                baseLocalization: LocalizedFileReference,
                localizedFileRef: LocalizedFileReference,
                baseId: String,
                localizedFileRefId: String
            )
        }
        
        enum QuestionnaireIssue: Hashable, Sendable {
            case missingField(LocalizedFileReference, itemIdx: Int?, fieldName: String)
            case mismatchingFieldValues( // swiftlint:disable:this enum_case_associated_values_count
                baseFileRef: LocalizedFileReference,
                localizedFileRef: LocalizedFileReference,
                itemIdx: Int?,
                fieldName: String,
                baseValue: Value?,
                localizedValue: Value?
            )
            
            @_disfavoredOverload
            static func mismatchingFieldValues( // swiftlint:disable:this function_parameter_count type_contents_order
                baseFileRef: LocalizedFileReference,
                localizedFileRef: LocalizedFileReference,
                itemIdx: Int?,
                fieldName: String,
                baseValue: (some Hashable & Sendable)?,
                localizedValue: (some Hashable & Sendable)?
            ) -> Self {
                .mismatchingFieldValues(
                    baseFileRef: baseFileRef,
                    localizedFileRef: localizedFileRef,
                    itemIdx: itemIdx,
                    fieldName: fieldName,
                    baseValue: Value(baseValue),
                    localizedValue: Value(localizedValue)
                )
            }
            
            struct Value: Hashable, Sendable { // swiftlint:disable:this nesting
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
                static func == (lhs: Self, rhs: Self) -> Bool {
                    lhs.value.isEqual(rhs.value) && lhs.type == rhs.type
                }
                func hash(into hasher: inout Hasher) {
                    hasher.combine(ObjectIdentifier(type))
                    value.hash(into: &hasher)
                }
            }
        }
        
        var description: String {
            func desc(_ value: Any?) -> String {
                switch value {
                case nil:
                    "(nil)"
                case let value as FHIRPrimitive<FHIRString>:
                    (value.value?.string).map { "'\($0)'" } ?? "(nil)"
                case .some(let value):
                    String(describing: value)
                }
            }
            return switch self {
            case let .general(.noFilesMatchingFileRef(fileRef)):
                "No files matching file ref '\(fileRef)'"
            case let .article(.documentMetadataMissingId(fileRef)):
                "Article is missing 'id' in metadata: \(fileRef.filenameIncludingLocalization)"
            case let .article(.documentMetadataIdMismatchToBase(baseLocalization, fileRef, baseId, localizedFileRefId)):
                """
                Localized Article id does not match base localization's id
                    - base localization: \(baseLocalization.filenameIncludingLocalization)
                    - localized article: \(fileRef.filenameIncludingLocalization)
                    - base id: \(baseId)
                    - localized article id: \(localizedFileRefId)
                """
            case let .questionnaire(.missingField(fileRef, itemIdx, fieldName)):
                if let itemIdx {
                    "Questionnaire '\(fileRef.filenameIncludingLocalization)': item \(itemIdx) is missing value for field '\(fieldName)'"
                } else {
                    "Questionnaire '\(fileRef.filenameIncludingLocalization)': missing value for field '\(fieldName)'"
                }
            case let .questionnaire(.mismatchingFieldValues(baseFileRef, localizedFileRef, itemIdx, fieldName, baseValue, localizedValue)):
                """
                Localized Questionnaire: item field value does not match base localization
                    - base questionnaire: \(baseFileRef.filenameIncludingLocalization)
                    - localized questionnaire: \(localizedFileRef.filenameIncludingLocalization)
                    - item idx: \(itemIdx.map(String.init) ?? "n/a")
                    - fieldName: \(fieldName)
                    - base questionnaire value: \(desc(baseValue))
                    - localized questionnaire value: \(desc(localizedValue))
                """
            }
        }
    }
    
    
    /// Validates the StudyBundle.
    ///
    /// This function performs the following checks:
    /// - for informational components:
    ///     - check that each informational component's file ref can be resolved;
    ///     - check that for each article, all localized variants have the same `id` in their metadata;
    /// - for questionnaire components:
    ///     - check that each questionnaire component's file ref can be resolved;
    ///     - check that for each questionnaire, all localized variants share the following properties:
    ///         - questionnaire id
    ///         - number of items in the questionnaire
    ///         - item identifiers
    ///         - item types
    func validate() throws -> [BundleValidationIssue] {
        var issues: [BundleValidationIssue] = []
        issues.append(contentsOf: try validateArticles())
        issues.append(contentsOf: try validateQuestionnaires())
        return issues
    }
    
    
    private func validateQuestionnaires() throws -> [BundleValidationIssue] { // swiftlint:disable:this function_body_length
        let questionnaireFileRefs = studyDefinition.components.compactMap {
            switch $0 {
            case .questionnaire(let component):
                component.fileRef
            default:
                nil
            }
        }
        let fileManager = FileManager.default
        var issues: [BundleValidationIssue] = []
        for fileRef in questionnaireFileRefs {
            /// all files for this fileRef's category
            let urls = try fileManager.contentsOfDirectory(
                at: Self.folderUrl(for: fileRef.category, relativeTo: bundleUrl),
                includingPropertiesForKeys: nil
            )
            let candidates = LocalizedFileResolution.selectCandidatesIgnoringLocalization(
                matching: LocalizedFileResource(fileRef),
                from: urls
            )
            let questionnaires: [(questionnaire: Questionnaire, fileRef: LocalizedFileResource.Resolved)] = try candidates.map {
                (try JSONDecoder().decode(Questionnaire.self, from: try Data(contentsOf: $0.url)), $0)
            }
            func checkSingleQuestionnaire(_ questionnaire: Questionnaire, fileRef questionnaireFileRef: LocalizedFileResource.Resolved) {
                if questionnaire.id?.value == nil {
                    issues.append(.questionnaire(.missingField(
                        .init(fileRef: fileRef, localization: questionnaireFileRef.localization),
                        itemIdx: nil,
                        fieldName: "id"
                    )))
                }
                if questionnaire.title?.value == nil {
                    issues.append(.questionnaire(.missingField(
                        .init(fileRef: fileRef, localization: questionnaireFileRef.localization),
                        itemIdx: nil,
                        fieldName: "title"
                    )))
                }
                guard let items = questionnaire.item else {
                    issues.append(.questionnaire(.missingField(
                        .init(fileRef: fileRef, localization: questionnaireFileRef.localization),
                        itemIdx: nil,
                        fieldName: "item"
                    )))
                    return
                }
                for (idx, item) in items.enumerated() {
                    func checkHasValue(_ keyPath: KeyPath<QuestionnaireItem, (some Any)?>, _ name: String) {
                        if item[keyPath: keyPath] == nil {
                            issues.append(.questionnaire(.missingField(
                                .init(fileRef: fileRef, localization: questionnaireFileRef.localization),
                                itemIdx: idx,
                                fieldName: name
                            )))
                        }
                    }
                    checkHasValue(\.linkId.value, "linkId")
                    checkHasValue(\.text?.value, "text")
                }
            }
            let base = questionnaires.first { $0.0.language == "en-US" }
                ?? questionnaires.first { $0.0.language == "en" }
                ?? questionnaires.first! // swiftlint:disable:this force_unwrapping
            checkSingleQuestionnaire(base.questionnaire, fileRef: base.fileRef)
            for other in questionnaires.filter({ $0.fileRef != base.fileRef }) {
                checkSingleQuestionnaire(other.questionnaire, fileRef: other.fileRef)
                if base.questionnaire.id?.value?.string != other.questionnaire.id?.value?.string {
                    issues.append(.questionnaire(.mismatchingFieldValues(
                        baseFileRef: .init(fileRef: fileRef, localization: base.fileRef.localization),
                        localizedFileRef: .init(fileRef: fileRef, localization: other.fileRef.localization),
                        itemIdx: nil,
                        fieldName: "id",
                        baseValue: base.questionnaire.id?.value?.string,
                        localizedValue: other.questionnaire.id?.value?.string
                    )))
                }
                let baseItems = base.questionnaire.item ?? []
                let otherItems = other.questionnaire.item ?? []
                guard baseItems.count == otherItems.count else {
                    issues.append(.questionnaire(.mismatchingFieldValues(
                        baseFileRef: .init(fileRef: fileRef, localization: base.fileRef.localization),
                        localizedFileRef: .init(fileRef: fileRef, localization: other.fileRef.localization),
                        itemIdx: nil,
                        fieldName: "item.length",
                        baseValue: baseItems.count,
                        localizedValue: otherItems.count
                    )))
                    continue
                }
                for (idx, (baseItem, item)) in zip(baseItems, otherItems).enumerated() {
                    func checkEqual(_ keyPath: KeyPath<QuestionnaireItem, (some Hashable & Sendable)?>, _ name: String) {
                        let baseValue = baseItem[keyPath: keyPath]
                        let itemValue = item[keyPath: keyPath]
                        if baseValue != itemValue {
                            issues.append(.questionnaire(.mismatchingFieldValues(
                                baseFileRef: .init(fileRef: fileRef, localization: base.fileRef.localization),
                                localizedFileRef: .init(fileRef: fileRef, localization: other.fileRef.localization),
                                itemIdx: idx,
                                fieldName: name,
                                baseValue: baseValue,
                                localizedValue: itemValue
                            )))
                        }
                    }
                    checkEqual(\.linkId.value, "linkId")
                    checkEqual(\.type.value, "type")
                }
            }
        }
        return issues
    }
    
    
    private func validateArticles() throws -> [BundleValidationIssue] {
        let articleFileRefs = studyDefinition.components.compactMap {
            switch $0 {
            case .informational(let component):
                component.fileRef
            default:
                nil
            }
        }
        let fileManager = FileManager.default
        var issues: [BundleValidationIssue] = []
        for articleFileRef in articleFileRefs {
            /// all files for this fileRef's category
            let urls = try fileManager.contentsOfDirectory(
                at: Self.folderUrl(for: articleFileRef.category, relativeTo: bundleUrl),
                includingPropertiesForKeys: nil
            )
            let candidates = LocalizedFileResolution.selectCandidatesIgnoringLocalization(
                matching: LocalizedFileResource(articleFileRef),
                from: urls
            )
            guard !candidates.isEmpty else {
                issues.append(.general(.noFilesMatchingFileRef(articleFileRef)))
                continue
            }
            let documents = try candidates.map {
                (try MarkdownDocument(processingContentsOf: $0.url), $0)
            }
            let (baseDocument, baseDocumentFileRef) = documents.first { $0.1.localization == .enUS }
                ?? documents.first { $0.1.localization.language.isEquivalent(to: .init(identifier: "en")) }
                ?? documents.first! // swiftlint:disable:this force_unwrapping
            for (document, fileRef) in documents {
                guard let id = document.metadata["id"] else {
                    issues.append(.article(.documentMetadataMissingId(.init(fileRef: articleFileRef, localization: fileRef.localization))))
                    continue
                }
                guard id == baseDocument.metadata["id"] else {
                    issues.append(.article(.documentMetadataIdMismatchToBase(
                        baseLocalization: .init(fileRef: articleFileRef, localization: baseDocumentFileRef.localization),
                        localizedFileRef: .init(fileRef: articleFileRef, localization: fileRef.localization),
                        baseId: baseDocument.metadata["id"] ?? "nil", // never nil; implicitly checked above
                        localizedFileRefId: id
                    )))
                    continue
                }
            }
        }
        return issues
    }
}


extension LocalizedFileResource {
    init(_ other: StudyBundle.FileReference, locale: Locale = .autoupdatingCurrent) {
        self.init("\(other.category.rawValue)/\(other.filename).\(other.fileExtension)", locale: locale)
    }
}


extension QuestionnaireItemType: @retroactive @unchecked Sendable {}

extension Equatable {
    fileprivate func isEqual(_ other: Any) -> Bool {
        if let other = other as? Self {
            self == other
        } else {
            false
        }
    }
}
