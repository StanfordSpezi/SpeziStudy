//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable all

import Foundation
import class ModelsR4.Questionnaire
import SpeziFoundation
import UniformTypeIdentifiers
import OSLog


extension UTType {
    public static let speziStudyBundle = UTType(filenameExtension: "spezistudybundle", conformingTo: .package)!
}


/// A handle for working with a Study Definition bundle
public struct StudyBundle: Hashable, Identifiable, Sendable {
    public static let fileExtension = "spezistudybundle"
    
    private static let logger = Logger(subsystem: "edu.stanford.SpeziStudy", category: "StudyBundle")
    
    /// The file url of the study definition bundle.
    public let bundleUrl: URL
    public let studyDefinition: StudyDefinition // TODO what if the study bundle gets written to after we've read the StudyDef?
    
    public var id: UUID { studyDefinition.id }
    
    public init(bundleUrl: URL) throws {
        print("-[\(Self.self) \(#function)] loading bundle at \(bundleUrl.path)")
        guard bundleUrl.hasDirectoryPath && bundleUrl.pathExtension == Self.fileExtension else {
            fatalError() // TODO throw!
        }
        self.bundleUrl = bundleUrl
        do {
            let data = try Data(contentsOf: bundleUrl.appendingPathComponent("definition", conformingTo: .json))
            self.studyDefinition = try JSONDecoder().decode(StudyDefinition.self, from: data, configuration: .init(allowTrivialSchemaMigrations: true)) // TODO exposr!!
        }
    }
    
    
    public func copy(to dstUrl: URL) throws {
        precondition(dstUrl.pathExtension == Self.fileExtension) // TODO throw instead!
        let fm = FileManager.default
        try fm.copyItem(at: bundleUrl, to: dstUrl, overwriteExisting: true)
    }
    
    
    public func questionnaire(for fileRef: FileReference, locale: Locale) -> Questionnaire? {
        _decodeResource(for: fileRef, locale: locale) {
            try JSONDecoder().decode(Questionnaire.self, from: $0)
        }
    }
    
    public func consentText(for fileRef: FileReference, locale: Locale) -> String? {
        _decodeResource(for: fileRef, locale: locale) {
            String(data: $0, encoding: .utf8)
        }
    }
    
    
    private func _decodeResource<T>(for fileRef: FileReference, locale: Locale, decode: (Data) throws -> T?) -> T? {
        guard let url = resolve(fileRef: fileRef, locale: locale)?.0 else {
            return nil
        }
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? decode(data)
    }
    
    public func resolve(_ fileRef: FileReference, using locale: Locale) -> URL? {
        resolve(fileRef: fileRef, locale: locale)?.0
    }
    
    private func resolve(fileRef: FileReference, locale: Locale) -> (URL, FileReferenceWithLocalization)? {
        let FM = FileManager.default
        let dirUrl = Self.folderUrl(for: fileRef.category, relativeTo: bundleUrl)
        let candidates = ((try? FM.contents(of: dirUrl)) ?? [])
            .compactMap { url -> (URL, FileReferenceWithLocalization)? in
                Self.parse(filename: url.lastPathComponent, in: fileRef.category).map { (url, $0) }
            }
            .filter { $1.fileRef == fileRef }
            .map { (url: $0.0, fileRef: $0.1, score: $0.1.localization.score(against: locale)) }
            .sorted(using: KeyPathComparator(\.score, order: .reverse))
        guard let candidate = candidates.first, candidate.score > 0.5 else {
            Self.logger.error("Unable to find url for \(String(describing: fileRef)) and locale \(locale) (key: \(LocalizationKey(locale: locale))).")
            if candidates.isEmpty {
                Self.logger.error("No candidates")
            } else {
                Self.logger.error("Candidates:")
                for candidate in candidates {
                    Self.logger.error("- \(candidate.score) @ \(candidate.fileRef.fullFilenameIncludingLocalization)")
                }
            }
            return nil
        }
        do {
            let equallyBestRanked = candidates.chunked(by: { $0.score == $1.score }).first!
            guard equallyBestRanked.count == 1 else {
                fatalError("Found multiple candidates, all of which are equally ranked!")
            }
        }
        return (candidate.url, candidate.fileRef)
    }
    
    
    fileprivate struct FileReferenceWithLocalization {
        let fileRef: FileReference
        let localization: LocalizationKey
        
        var filenameIncludingLocalization: String {
            "\(fileRef.filename)+\(localization.description)"
        }
        
        var fullFilenameIncludingLocalization: String {
            "\(fileRef.filename)+\(localization.description).\(fileRef.fileExtension)"
        }
    }
    
    // TODO test this!!!
    private static func parse(filename: String, in category: FileReference.Category) -> FileReferenceWithLocalization? {
        guard filename.contains("+") else {
            logger.error("invalid file name '\(filename)'")
            return nil
        }
        var filename = filename[...]
        let baseName = String(filename.prefix { $0 != "+" })
        filename.removeFirst(baseName.count + 1)
        let rawLocalization = String(filename.prefix { $0 != "." })
        filename.removeFirst(rawLocalization.count + 1)
        let fileExtension = String(filename)
        guard let localization = LocalizationKey(rawLocalization) else {
            logger.error("failed to parse '\(rawLocalization)' into a localization")
            return nil
        }
        return .init(
            fileRef: FileReference(category: category, filename: baseName, fileExtension: fileExtension),
            localization: localization
        )
    }
}


extension StudyBundle {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(bundleUrl)
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.bundleUrl == rhs.bundleUrl
    }
}

extension StudyBundle {
    public struct File {
        fileprivate let localizedFileRef: FileReferenceWithLocalization
        let contents: Data
        
        public init(fileRef: FileReference, localization: LocalizationKey, contents: Data) {
            self.localizedFileRef = .init(fileRef: fileRef, localization: localization)
            self.contents = contents
        }
        
        public init(fileRef: FileReference, localization: LocalizationKey, contents: String) throws {
            self.localizedFileRef = .init(fileRef: fileRef, localization: localization)
            guard let contents = contents.data(using: .utf8) else {
                throw NSError(domain: "edu.stanford.SpeziStudy", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Unable to obtain UTF-8 representation of input String"
                ])
            }
            self.contents = contents
        }
        
        public init(fileRef: FileReference, localization: LocalizationKey, contents: some Encodable) throws {
            self.localizedFileRef = .init(fileRef: fileRef, localization: localization)
            self.contents = try JSONEncoder().encode(contents)
        }
    }
    
    
    public enum WriteToDiskError: Error {
        case invalidFileCategory
    }
    
    public static func writeToDisk(
        at bundleUrl: URL,
        definition: StudyDefinition,
        files: [File]
    ) throws -> StudyBundle {
        precondition(bundleUrl.pathExtension == Self.fileExtension)
        let FM = FileManager.default
        try? FM.removeItem(at: bundleUrl)
        try FM.createDirectory(at: bundleUrl, withIntermediateDirectories: true)
        do {
            let data = try JSONEncoder().encode(definition)
            try data.write(to: bundleUrl.appendingPathComponent("definition", conformingTo: .json))
        }
        for file in files {
            let fileUrl = Self.fileUrl(for: file.localizedFileRef, relativeTo: bundleUrl)
            try FM.prepareForWriting(to: fileUrl)
            try file.contents.write(to: fileUrl)
        }
        return try Self(bundleUrl: bundleUrl)
    }
    
    
    private static func folderUrl(for category: FileReference.Category, relativeTo baseUrl: URL) -> URL {
        baseUrl.appending(component: category.rawValue, directoryHint: .isDirectory)
    }
    
    private static func fileUrl(for fileRef: FileReference, relativeTo baseUrl: URL) -> URL {
        folderUrl(for: fileRef.category, relativeTo: baseUrl)
            .appending(component: fileRef.filename, directoryHint: .notDirectory)
            .appendingPathExtension(fileRef.fileExtension)
    }
    
    private static func fileUrl(for localizedFileRef: FileReferenceWithLocalization, relativeTo baseUrl: URL) -> URL {
        folderUrl(for: localizedFileRef.fileRef.category, relativeTo: baseUrl)
            .appending(component: localizedFileRef.filenameIncludingLocalization, directoryHint: .notDirectory)
            .appendingPathExtension(localizedFileRef.fileRef.fileExtension)
    }
}


extension StudyBundle {
    /// A reference to a non-localized version of a file within the bundle
    public struct FileReference: Hashable, Sendable, Codable, CustomStringConvertible {
        public struct Category: RawRepresentable, Hashable, Codable, Sendable {
            public let rawValue: String
            
            public init(rawValue: String) {
                self.rawValue = rawValue
            }
            
            public init(from decoder: any Decoder) throws {
                let container = try decoder.singleValueContainer()
                rawValue = try container.decode(String.self)
            }
            
            public func encode(to encoder: any Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(rawValue)
            }
            
            public static let consent = Self(rawValue: "consent")
            public static let questionnaire = Self(rawValue: "questionnaire")
            public static let informationalArticle = Self(rawValue: "informationalArticle")
        }
        
        public let category: Category
        public let filename: String
        public let fileExtension: String
        
        public var description: String {
            "\(category.rawValue)/\(filename).\(fileExtension)"
        }
        
        public init(category: Category, filename: String, fileExtension: String) {
            self.category = category
            self.filename = filename
            self.fileExtension = fileExtension
        }
    }
    
    
    public struct LocalizationKey: Hashable, LosslessStringConvertible, Sendable {
        public let language: Locale.Language
        public let region: Locale.Region
        
        public var description: String {
            language.minimalIdentifier + "-" + region.identifier
        }
        
        public init(locale: Locale) {
            self.init(language: locale.language, region: locale.region!)
        }
        
        public init(language: Locale.Language, region: Locale.Region) {
            self.language = language
            self.region = region
        }
        
        public init?(_ description: String) {
            let components = description.split(separator: "-")
            guard components.count == 2 else {
                return nil
            }
            let languageIdentifier = components[0]
            let regionIdentifier = components[1]
            guard let language = Locale.Language.systemLanguages.first(where: { $0.minimalIdentifier == languageIdentifier }),
                  let region = Locale.Region.isoRegions.first(where: { $0.identifier == regionIdentifier }) else {
                return nil
            }
            self.init(language: language, region: region)
        }
        
        func score(against locale: Locale) -> Double {
            let languageMatches = locale.language.minimalIdentifier == self.language.minimalIdentifier
            let regionMatches = locale.region?.identifier == self.region.identifier // TODO also allow mayching against parent regions? (eg: if the user is in DE, but the region in the key is EU, that should match...)
            switch (languageMatches, regionMatches) {
            case (true, true):
                return 1 // perfect score
            case (true, false): // correct language, wrong region
                return 0
            case (false, true): // correct region, wrong language
                return 0.75
            case (false, false): // nothing matches :/
                return 0
            }
        }
    }
}
