//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Combine
import Foundation
import SwiftData
import SwiftUI

typealias SwiftTask = _Concurrency.Task


@propertyWrapper
struct NotNilAssignable<T> {
    private var value: T?
    
    var wrappedValue: T? {
        get { value }
        set {
            if let newValue {
                value = newValue
            } else {
                // if someone tries to assign nil, we keep the current value.
            }
        }
    }
    
    init() {
        value = nil
    }
    
    init(wrappedValue: T?) {
        value = wrappedValue
    }
}

extension NotNilAssignable: Sendable where T: Sendable {}


extension RangeReplaceableCollection {
    func appending(_ element: Element) -> Self {
        var copy = self
        copy.append(element)
        return copy
    }
    
    func appending(contentsOf other: some Sequence<Element>) -> Self {
        var copy = self
        copy.append(contentsOf: other)
        return copy
    }
}
