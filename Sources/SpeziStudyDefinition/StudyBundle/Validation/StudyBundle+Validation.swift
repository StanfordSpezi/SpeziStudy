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
    @_spi(APISupport)
    public enum BundleValidationIssue: ErrorMessageConvertible, Hashable, Sendable {
        case general(GeneralIssue)
        case article(ArticleIssue)
        case questionnaire(QuestionnaireIssue)
        
        public enum GeneralIssue: Hashable, Sendable {
            /// The study bundle doesn't contain any files that would match the file reference found in the study definition.
            case noFilesMatchingFileRef(StudyBundle.FileReference)
        }
        
        public enum ArticleIssue: Hashable, Sendable {
            case documentMetadataMissingId(fileRef: LocalizedFileReference)
            case documentMetadataIdMismatchToBase(
                baseLocalization: LocalizedFileReference,
                localizedFileRef: LocalizedFileReference,
                baseId: String,
                localizedFileRefId: String
            )
        }
        
        public var errorMessage: ErrorMessage {
            switch self {
            case let .general(.noFilesMatchingFileRef(fileRef)):
                "No files matching file ref '\(fileRef)'"
            case let .article(.documentMetadataMissingId(fileRef)):
                "Article is missing 'id' in metadata: \(fileRef.filenameIncludingLocalization)"
            case let .article(.documentMetadataIdMismatchToBase(baseLocalization, fileRef, baseId, localizedFileRefId)):
                ErrorMessage("Localized Article id does not match base localization's id") {
                    ErrorMessage.Item("base localization", value: baseLocalization)
                    ErrorMessage.Item("localized article", value: fileRef)
                    ErrorMessage.Item("base id", value: baseId)
                    ErrorMessage.Item("localized articleid", value: localizedFileRefId)
                }
            case let .questionnaire(.missingField(fileRef, path, comment)):
                ErrorMessage("Questionnaire: missing field value") {
                    ErrorMessage.Item("file", value: fileRef)
                    ErrorMessage.Item("path", value: path)
                    ErrorMessage.Item("comment", omitIfNil: true, value: comment)
                }
            case let .questionnaire(.invalidField(fileRef, path, fieldValue, failureReason)):
                ErrorMessage("Questionnaire: invalid field value") {
                    ErrorMessage.Item("file", value: fileRef)
                    ErrorMessage.Item("path", value: path)
                    ErrorMessage.Item("value", value: fieldValue)
                    ErrorMessage.Item("issue", value: failureReason)
                }
            case let .questionnaire(.conflictingFieldValues(fileRef, fstPath, fstValue, sndPath, sndValue, comment)):
                ErrorMessage("Conflicting field values withon questionnaire") {
                    ErrorMessage.Item("questionnaire", value: fileRef)
                    ErrorMessage.Item("1st value path", value: fstPath)
                    ErrorMessage.Item("1st value", value: fstValue)
                    ErrorMessage.Item("2nd value path", value: sndPath)
                    ErrorMessage.Item("2nd value", value: sndValue)
                    ErrorMessage.Item("comment", omitIfNil: true, value: comment)
                }
            case let .questionnaire(.mismatchingFieldValues(baseFileRef, localizedFileRef, path, baseValue, localizedValue)):
                ErrorMessage("Localized Questionnaire: field value does not match base localization") {
                    ErrorMessage.Item("base questionnaire", value: baseFileRef)
                    ErrorMessage.Item("localized questionnaire", value: localizedFileRef)
                    ErrorMessage.Item("path", value: path)
                    ErrorMessage.Item("base questionnaire value", value: baseValue)
                    ErrorMessage.Item("localized questionnaire value", value: localizedValue)
                }
            case let .questionnaire(.languageDiffersFromFilenameLocalization(fileRef, questionnaireLanguage)):
                ErrorMessage("Questionnaire: language in metadata does not match filename localization component") {
                    ErrorMessage.Item("questionnaire", value: fileRef)
                    ErrorMessage.Item("metadata lang", value: questionnaireLanguage)
                }
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
        issues.append(contentsOf: try validateQuestionnaires().map { .questionnaire($0) })
        return issues
    }
}


// MARK: Helpers

extension LocalizedFileResource {
    init(_ other: StudyBundle.FileReference, locale: Locale = .autoupdatingCurrent) {
        self.init("\(other.category.rawValue)/\(other.filename).\(other.fileExtension)", locale: locale)
    }
}
