//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation


final class JSONEncodingValueTransformer<T: Codable & AnyObject>: ValueTransformer {
    override class func transformedValueClass() -> AnyClass {
        T.self
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        guard let value = value as? T else {
            preconditionFailure("Invalid input: Expected input of type '\(T.self)'; got '\(type(of: value))'")
        }
        return try! JSONEncoder().encode(value) as NSData // swiftlint:disable:this force_try
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else {
            preconditionFailure("Invalid input: Expected input of type '\(Data.self)'; got '\(type(of: value))'")
        }
        return try! JSONDecoder().decode(T.self, from: data) // swiftlint:disable:this force_try
    }
}
