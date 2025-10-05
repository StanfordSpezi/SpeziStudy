//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziLocalization


extension StudyBundle {
    /// An error that can occur when creating a Study Bundle.
    public enum CreateBundleError: Error {
        /// The ``StudyDefinition`` for which a ``StudyBundle`` should be created contains a ``FileReference``
        /// pointing to a file which was not supplied to the ``StudyBundle/writeToDisk(at:definition:files:)`` function.
        /// - parameter fileRef: The file ref in question.
        case missingFile(fileRef: FileReference)
        
        /// A `String` passed to e.g. ``StudyBundle/FileInput/init(fileRef:localization:contents:)-(_,_,String)`` didn't have a valid UTF-8 representation.
        case nonUTF8Input
        
        /// The Study Bundle failed to pass the validation checks.
        case failedValidation(reason: String)
    }
    
    
    /// A file which should be included when creating a ``StudyBundle``.
    public struct FileInput {
        /// The file's name, extension, and localization info.
        let localizedFileRef: LocalizedFileReference
        /// The raw contents of the file
        let contents: Data
        
        /// Creates a new `FileInput`, from raw `Data`.
        public init(fileRef: FileReference, localization: LocalizationKey, contents: Data) {
            self.localizedFileRef = .init(fileRef: fileRef, localization: localization)
            self.contents = contents
        }
        
        /// Creates a new `FileInput`, from UTF8-encoded text.
        public init(fileRef: FileReference, localization: LocalizationKey, contents: String) throws(CreateBundleError) {
            self.localizedFileRef = .init(fileRef: fileRef, localization: localization)
            guard let contents = contents.data(using: .utf8) else {
                throw .nonUTF8Input
            }
            self.contents = contents
        }
        
        /// Creates a new `FileInput`, from an `Encodable` value.
        public init(fileRef: FileReference, localization: LocalizationKey, contents: some Encodable) throws {
            self.localizedFileRef = .init(fileRef: fileRef, localization: localization)
            self.contents = try JSONEncoder().encode(contents)
        }
        
        /// Creates a new `FileInput`, with the file contents at the specified URL.
        public init(fileRef: FileReference, localization: LocalizationKey, contentsOf url: URL) throws {
            self.localizedFileRef = .init(fileRef: fileRef, localization: localization)
            self.contents = try Data(contentsOf: url)
        }
    }
    
    /// Creates a new Study Bundle, from the specified inputs.
    public static func writeToDisk(
        at bundleUrl: URL,
        definition: StudyDefinition,
        files: [FileInput]
    ) throws -> StudyBundle {
        try Self.assertIsStudyBundleUrl(bundleUrl)
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: bundleUrl)
        try fileManager.createDirectory(at: bundleUrl, withIntermediateDirectories: true)
        do {
            let data = try JSONEncoder().encode(definition)
            try data.write(to: bundleUrl.appendingPathComponent("definition", conformingTo: .json))
        }
        for file in files {
            let fileUrl = Self.fileUrl(for: file.localizedFileRef, relativeTo: bundleUrl)
            try fileManager.prepareForWriting(to: fileUrl)
            try file.contents.write(to: fileUrl)
        }
        let bundle = try Self(bundleUrl: bundleUrl)
        if case let issues = try bundle.validate(), !issues.isEmpty {
            try? fileManager.removeItem(at: bundle.bundleUrl)
            throw CreateBundleError.failedValidation(reason: issues.map { "- \($0.description)" }.joined(separator: "\n"))
        }
        return bundle
    }
}


extension StudyDefinition {
    var allFileRefs: Set<StudyBundle.FileReference> {
        var fileRefs = Set<StudyBundle.FileReference>()
        if let consentFile = metadata.consentFileRef {
            fileRefs.insert(consentFile)
        }
        for component in self.components {
            switch component {
            case .informational(let component):
                fileRefs.insert(component.fileRef)
            case .questionnaire(let component):
                fileRefs.insert(component.fileRef)
            case .healthDataCollection, .timedWalkingTest, .customActiveTask:
                break
            }
        }
        return fileRefs
    }
}
