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


extension Calendar.RecurrenceRule: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        for child in Mirror(reflecting: self).children {
            if let hashable = child.value as? any Hashable {
                hashable.hash(into: &hasher)
            } else {
                fatalError("Cannot hash child \(child)")
            }
        }
    }
}


extension Calendar.RecurrenceRule.Weekday: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .every(let weekday):
            hasher.combine(weekday)
        case let .nth(interval, weekday):
            hasher.combine(interval)
            hasher.combine(weekday)
        @unknown default:
            fatalError("Cannot hash \(self)")
        }
    }
}
