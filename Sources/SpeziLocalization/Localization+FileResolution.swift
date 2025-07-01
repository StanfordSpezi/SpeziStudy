//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Algorithms
import Foundation


extension Localization {
    public static func resolveFile(
        named filename: String,
        from candidates: some Collection<URL>,
        locale: Locale,
        using localeMatchingBehaviour: LocaleMatchingBehaviour = .preferLanguageMatch,
        fallback fallbackLocale: LocalizationKey? = .enUS
    ) -> (url: URL, localization: LocalizationKey)? {
        let candidates = candidates
            .compactMap { (url: URL) -> (URL, LocalizedFilenameParsingResult)? in
                Self.parseLocalizedFilename(url.lastPathComponent).map { (url, $0) }
            }
            .filter { $1.unlocalizedFilename == filename }
            .map { (url: $0.0, parseResult: $0.1, score: $0.1.localization.score(against: locale, using: localeMatchingBehaviour)) }
            .sorted(using: KeyPathComparator(\.score, order: .reverse))
        guard let candidate = candidates.first, candidate.score > 0.5 else {
            Self.logger.error("Unable to find url for \(filename) and locale \(locale) (key: \(LocalizationKey(locale: locale))).")
            if candidates.isEmpty {
                Self.logger.error("No candidates")
            } else {
                Self.logger.error("Candidates:")
                for candidate in candidates {
                    Self.logger.error("- \(candidate.score) @ \(candidate.parseResult.fullFilenameIncludingLocalization)")
                }
            }
            if let fallbackLocale, let fallback = candidates.first(where: { $0.parseResult.localization == fallbackLocale }) {
                Self.logger.warning("Falling back to \(fallbackLocale) locale.")
                return (fallback.url, fallback.parseResult.localization)
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
                    Self.logger.error("- \(candidate.score) @ \(candidate.parseResult.fullFilenameIncludingLocalization)")
                }
                fatalError("Found multiple candidates, all of which are equally ranked!")
            }
        }
        return (candidate.url, candidate.parseResult.localization)
    }
}


extension Localization {
    public struct LocalizedFilenameParsingResult: Hashable, Sendable {
        public let unlocalizedFilename: String
        public let localization: LocalizationKey
        
        public var fullFilenameIncludingLocalization: String {
            guard let baseNameEndIdx = unlocalizedFilename.firstIndex(of: ".") else {
                return unlocalizedFilename
            }
            return "\(unlocalizedFilename[..<baseNameEndIdx])+\(localization)\(unlocalizedFilename[baseNameEndIdx...])"
        }
    }
    
    public static func parseLocalizedFilename(_ filename: String) -> LocalizedFilenameParsingResult? {
        guard filename.contains("+") else {
            return nil
        }
        var filename = filename[...]
        let baseName = String(filename.prefix { $0 != "+" })
        filename.removeFirst(baseName.count + 1)
        let rawLocalization = String(filename.prefix { $0 != "." })
        filename.removeFirst(rawLocalization.count + 1)
        let fileExtension = String(filename)
        guard let localization = LocalizationKey(rawLocalization) else {
            return nil
        }
        return .init(unlocalizedFilename: "\(baseName).\(fileExtension)", localization: localization)
    }
}


extension LocalizationKey {
    public init?(parsingFilename filename: String) {
//        guard filename.contains("+") else {
//            return nil
//        }
//        var filename = filename[...]
//        let baseName = String(filename.prefix { $0 != "+" })
//        filename.removeFirst(baseName.count + 1)
//        let rawLocalization = String(filename.prefix { $0 != "." })
//        filename.removeFirst(rawLocalization.count + 1)
//        let fileExtension = String(filename)
//        self.init(rawLocalization)
        guard let parseResult = Localization.parseLocalizedFilename(filename) else {
            return nil
        }
        self = parseResult.localization
    }
}
