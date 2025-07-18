//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation


extension RangeReplaceableCollection {
    /// Returns the collection obtained by appending an element to the collection.
    func appending(_ element: Element) -> Self {
        var copy = self
        copy.append(element)
        return copy
    }
    
    
    /// Returns the collection obtained by appending a sequence to the collection.
    func appending(contentsOf other: some Sequence<Element>) -> Self {
        var copy = self
        copy.append(contentsOf: other)
        return copy
    }
}


extension Locale {
    /// Creates a new Locale, with the specified language and region.
    public init(language: Language, region: Region) {
        var components = Components(
            languageCode: language.languageCode,
            languageRegion: language.region
        )
        components.region = region
        self.init(components: components)
    }
}
