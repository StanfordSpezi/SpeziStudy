//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


extension StudyDefinition {
    public struct SchemaVersion: Hashable, Sendable {
        public let major: UInt
        public let minor: UInt
        public let patch: UInt
        
        public init(major: UInt, minor: UInt, patch: UInt) {
            self.major = major
            self.minor = minor
            self.patch = patch
        }
    }
}


extension StudyDefinition.SchemaVersion: Comparable {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}


extension StudyDefinition.SchemaVersion {
    public enum Component {
        case major, minor, patch
    }
    
//    /// Determines whether a `SchemaVersion` is compatible with another version, up to the specified component.
//    ///
//    /// E.g.: `1.0.1` compares as compatible with `1`
//    public func matches(other: Self, upToNext component: Component) -> Bool {
//        switch component {
//        case .major:
//            self.major == other.major
//        case .minor:
//            self.major == other.major
//        case .patch:
//            <#code#>
//        }
//    }
}


extension StudyDefinition.SchemaVersion: LosslessStringConvertible, Codable {
    public enum ParseError: Error {
        case unableToParseVersion
    }
    
    public var description: String {
        "\(major).\(minor).\(patch)"
    }
    
    public init?(_ description: String) {
        let pattern = /^(?<major>[0-9]+).(?<minor>[0-9]+).(?<patch>[0-9]+)$/
        guard let match = try? pattern.wholeMatch(in: description) else {
            return nil
        }
        guard let major = UInt(match.output.major),
              let minor = UInt(match.output.minor),
              let patch = UInt(match.output.patch) else {
            return nil
        }
        self.init(major: major, minor: minor, patch: patch)
    }
    
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        if let version = Self(string) {
            self = version
        } else {
            throw ParseError.unableToParseVersion
        }
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
