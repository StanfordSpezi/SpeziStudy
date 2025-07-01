//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
@testable import SpeziLocalization
import Testing


@Suite
struct LocalizationTests {
    @Test
    func parseFilename() throws {
        let result = try #require(Localization.parseLocalizedFilename("Consent+en-US.md"))
        #expect(result.unlocalizedFilename == "Consent.md")
        #expect(result.fullFilenameIncludingLocalization == "Consent+en-US.md")
        #expect(result.localization == .enUS)
    }
    
    @Test
    func resolveFromList() throws {
        let inputUrls = [
            "/news/Welcome.md",
            "/news/Welcome+en-US.md",
            "/news/Welcome+es-US.md",
            "/news/Welcome+en-UK.md",
            "/news/Welcome+de-DE.md",
            "/news/Update.md",
            "/news/Update+en-US.md",
            "/news/Update+es-US.md",
            "/news/Update+de-US.md"
        ].map { URL(filePath: $0) }
        print(inputUrls)
        
        do {
            let result = try #require(
                Localization.resolveFile(named: "Welcome.md", from: inputUrls, locale: .enUS, using: .requirePerfectMatch)
            )
            #expect(result.url == URL(filePath: "/news/Welcome+en-US.md"))
            #expect(result.localization == .enUS)
        }
        // TODO support this!
//        do {
//            let result = try #require(
//                Localization.resolveFile(named: "/news/Welcome.md", from: inputUrls, locale: .init(identifier: "en-US"), using: .requirePerfectMatch)
//            )
//            #expect(result.url == URL(filePath: "/news/Welcome+en-US.md"))
//            #expect(result.localization == .enUS)
//        }
        do {
            #expect(Localization.resolveFile(named: "Welcome.md", from: inputUrls, locale: .deDE) != nil)
            #expect(Localization.resolveFile(named: "Welcome.md", from: inputUrls, locale: .deUS) != nil)
            #expect(Localization.resolveFile(named: "Welcome.md", from: inputUrls, locale: .deUS, using: .requirePerfectMatch, fallback: nil) == nil)
        }
        do {
            let result = try #require(
                Localization.resolveFile(named: "Update.md", from: inputUrls, locale: .enUS, using: .requirePerfectMatch)
            )
            #expect(result.url == URL(filePath: "/news/Update+en-US.md"))
            #expect(result.localization == .enUS)
        }
        for behaviour in [LocaleMatchingBehaviour.requirePerfectMatch, .preferRegionMatch, .preferLanguageMatch] {
            let result = try #require(
                Localization.resolveFile(named: "Update.md", from: inputUrls, locale: .enUS, using: behaviour)
            )
            #expect(result.url == URL(filePath: "/news/Update+en-US.md"))
            #expect(result.localization == .enUS)
        }
    }
}


extension Locale {
    static let enUS = Self(identifier: "en_US")
    static let enUK = Self(identifier: "en_UK")
    static let esUS = Self(identifier: "es_US")
    static let esUK = Self(identifier: "es_UK")
    static let deDE = Self(identifier: "de_DE")
    static let deUS = Self(identifier: "de_US")
}
