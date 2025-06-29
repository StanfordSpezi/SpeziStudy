//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation


extension StudyBundle {
    /// A reference to a non-localized version of a file within a StudyBundle.
    ///
    /// ``FileReference``s are non-localized references to files stored within a ``StudyBundle``; they can be resolved against a specific `Locale` using ``StudyBundle/resolve(_:in:using:)``.
    public struct FileReference: Hashable, Sendable, Codable, CustomStringConvertible {
        /// A ``StudyBundle/FileReference``'s category.
        ///
        /// ## Topics
        ///
        /// ### File Categories
        /// - ``consent``
        /// - ``questionnaire``
        /// - ``informationalArticle``
        ///
        /// ### Creating new File Categories
        /// - ``init(rawValue:)``
        public struct Category: RawRepresentable, Hashable, Codable, Sendable {
            /// The File Category for Consent documents.
            public static let consent = Self(rawValue: "consent")
            /// The File Category for questionnaires.
            public static let questionnaire = Self(rawValue: "questionnaire")
            /// The File Category for informative articles.
            public static let informationalArticle = Self(rawValue: "informationalArticle")
            
            public let rawValue: String
            
            /// Creates a new file category
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
        }
        
        /// The file category
        public let category: Category
        /// The filename, without localization or extension.
        public let filename: String
        /// The file extension.
        public let fileExtension: String
        
        public var description: String {
            "\(category.rawValue)/\(filename).\(fileExtension)"
        }
        
        /// Creates a new file reference.
        public init(category: Category, filename: String, fileExtension: String) {
            self.category = category
            self.filename = filename
            self.fileExtension = fileExtension
        }
    }
}


extension StudyBundle {
    /// Locale information used to localize files, and to resolve them.
    ///
    /// A ``LocalizationKey`` consists of a ``language`` and a ``region``.
    public struct LocalizationKey: Hashable, LosslessStringConvertible, Sendable {
        static let enUS = Self(language: .init(identifier: "en"), region: .unitedStates)
        
        public let language: Locale.Language
        public let region: Locale.Region
        
        public var description: String {
            language.minimalIdentifier + "-" + region.identifier
        }
        
        public init(locale: Locale) {
            guard let region = locale.region else {
                // this should be exceedingly unlikely to happen: https://stackoverflow.com/a/74563008
                preconditionFailure("Invalid input: locale.region is nil")
            }
            self.init(language: locale.language, region: region)
        }
        
        public init(language: Locale.Language, region: Locale.Region) {
            self.language = language
            self.region = region
        }
        
        /// Attempts to create a Localization Key, by parsing the input.
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
        
        /// Match a Localization Key against a Locale.
        ///
        /// Determines how well the LocalizationKey matches the Locale, on a scale from 0 to 1.
        func score(against locale: Locale, using localeMatchingBehaviour: LocaleMatchingBehaviour) -> Double {
            let languageMatches = if let selfCode = self.language.languageCode, let otherCode = locale.language.languageCode {
                selfCode.identifier == otherCode.identifier
            } else {
                self.language.minimalIdentifier == locale.language.minimalIdentifier
            }
            // IDEA: maybe also allow matching against parent regions?
            // (eg: if the user is in Canada, but the region in the key is just north america in general, that should still match...)
            let regionMatches = locale.region?.identifier == self.region.identifier
            guard !(languageMatches && regionMatches) else { // perfect match
                return 1
            }
            switch localeMatchingBehaviour {
            case .requirePerfectMatch:
                return 0 // we've already checked for a perfect match above...
            case .preferLanguageMatch:
                return languageMatches ? 0.8 : regionMatches ? 0.75 : 0
            case .preferRegionMatch:
                return regionMatches ? 0.8 : languageMatches ? 0.75 : 0
            case .custom(let imp):
                return imp(self, .init(locale: locale))
            }
        }
    }
    
    
    /// A localized file reference is the combination of a ``FileReference`` and a ``LocalizationKey``
    struct LocalizedFileReference: Hashable, Sendable {
        let fileRef: FileReference
        let localization: LocalizationKey
        
        var filenameIncludingLocalization: String {
            "\(fileRef.filename)+\(localization.description)"
        }
        
        var fullFilenameIncludingLocalization: String {
            "\(fileRef.filename)+\(localization.description).\(fileRef.fileExtension)"
        }
    }
}


// MARK: URL/path resolution

extension StudyBundle {
    /// How a `Locale` should be matched against a localized Study Bundle resource's localization key.
    ///
    /// ## Topics
    ///
    /// ### Enumeration Cases
    /// - ``requirePerfectMatch``
    /// - ``preferLanguageMatch``
    /// - ``preferRegionMatch``
    /// - ``custom(_:)``
    public enum LocaleMatchingBehaviour {
        /// Only perfect matches are allowed
        ///
        /// If no perfect match exists, but there does exist a match where e.g. the resource's language matches but its region doesn't, it will still get ignored.
        case requirePerfectMatch
        /// If no perfect match exists, prefer partial matches where the language matches but the region does not over those where the region matches but the language does not.
        ///
        /// When using this option, perfect matches will still always take precedence over partial ones.
        case preferLanguageMatch
        /// If no perfect match exists, prefer partial matches where the region matches but the language does not over those where the language matches but the region does not.
        ///
        /// When using this option, perfect matches will still always take precedence over partial ones.
        case preferRegionMatch
        /// The matching should happen based on a fully custom behaviour.
        ///
        /// - parameter match: A closure that determines how well two ``LocalizationKey``s match.
        ///     The closure should return a score in the range `0...1`; any values exceeding that range will get clamped.
        case custom(_ match: (LocalizationKey, LocalizationKey) -> Double)
        
        /// The default matching behaviour
        @inlinable public static var `default`: Self { .preferLanguageMatch }
    }
    
    static func folderUrl(for category: FileReference.Category, relativeTo baseUrl: URL) -> URL {
        baseUrl.appending(component: category.rawValue, directoryHint: .isDirectory)
    }
    
    static func fileUrl(for fileRef: FileReference, relativeTo baseUrl: URL) -> URL {
        folderUrl(for: fileRef.category, relativeTo: baseUrl)
            .appending(component: fileRef.filename, directoryHint: .notDirectory)
            .appendingPathExtension(fileRef.fileExtension)
    }
    
    static func fileUrl(for localizedFileRef: LocalizedFileReference, relativeTo baseUrl: URL) -> URL {
        folderUrl(for: localizedFileRef.fileRef.category, relativeTo: baseUrl)
            .appending(component: localizedFileRef.filenameIncludingLocalization, directoryHint: .notDirectory)
            .appendingPathExtension(localizedFileRef.fileRef.fileExtension)
    }
    
    
    static func parse(filename: String, in category: FileReference.Category) -> LocalizedFileReference? {
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
    
    /// Resolves a `FileReference`, based on a locale.
    ///
    /// This function will fetch a list of all resources matching the ``FileReference``, and select the one with the best-matching locale.
    ///
    /// - Note: it is not guaranteed that the `URL` returned points to a file with a perfectly
    ///
    /// - returns: The `URL` of the resolved ``FileReference``, or `nil`
    public func resolve(
        _ fileRef: FileReference,
        in locale: Locale,
        using localeMatchingBehaviour: LocaleMatchingBehaviour = .default
    ) -> URL? {
        resolve(
            fileRef: fileRef,
            locale: locale,
            localeMatchingBehaviour: localeMatchingBehaviour
        )?.url
    }
    
    func resolve(
        fileRef: FileReference,
        locale: Locale,
        localeMatchingBehaviour: LocaleMatchingBehaviour
    ) -> (url: URL, localizedFileRef: LocalizedFileReference)? {
        let dirUrl = Self.folderUrl(for: fileRef.category, relativeTo: bundleUrl)
        let candidates = ((try? FileManager.default.contents(of: dirUrl)) ?? [])
            .compactMap { url -> (URL, LocalizedFileReference)? in
                Self.parse(filename: url.lastPathComponent, in: fileRef.category).map { (url, $0) }
            }
            .filter { $1.fileRef == fileRef }
            .map { (url: $0.0, fileRef: $0.1, score: $0.1.localization.score(against: locale, using: localeMatchingBehaviour)) }
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
            if let fallback = candidates.first(where: { $0.fileRef.localization == .enUS }) {
                Self.logger.warning("Falling back to en-US locale.")
                return (fallback.url, fallback.fileRef)
            }
            return nil
        }
        do {
            // SAFETY: we've checked above that there is at least one element in the array.
            // swiftlint:disable:next force_unwrapping
            let equallyBestRanked = candidates.chunked(by: { $0.score == $1.score }).first!
            guard equallyBestRanked.count == 1 else {
                Self.logger.error("Candidates:")
                for candidate in candidates {
                    Self.logger.error("- \(candidate.score) @ \(candidate.fileRef.fullFilenameIncludingLocalization)")
                }
                fatalError("Found multiple candidates, all of which are equally ranked!")
            }
        }
        return (candidate.url, candidate.fileRef)
    }
}
