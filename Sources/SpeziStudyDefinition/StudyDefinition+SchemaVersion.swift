//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


extension StudyDefinition {
    /// Version of the ``StudyDefinition`` schema.
    public struct SchemaVersion: Hashable, Sendable {
        /// Major version component
        public let major: UInt
        /// Minor version component
        public let minor: UInt
        /// Patch version component
        public let patch: UInt
        
        /// Creates a new `SchemaVersion`, from the specified components
        public init(_ major: UInt, _ minor: UInt, _ patch: UInt) {
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


extension StudyDefinition.SchemaVersion: LosslessStringConvertible, Codable {
    /// An error that occurre when parsing a ``SchemaVersion`` from a `String`.
    public enum ParseError: Error {
        /// The input string did not contain a valid ``SchemaVersion``
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
        self.init(major, minor, patch)
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
