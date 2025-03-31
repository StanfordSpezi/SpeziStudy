//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


//private class CodingKeysBase: CustomDebugStringConvertible, CustomStringConvertible {
//    static let schemaVersion = Self(stringValue: "schemaVersion")
//    
//    let stringValue: String
//    var intValue: Int? { nil }
//    
//    required init?(stringValue: String) {
//        self.stringValue = stringValue
//    }
//    
//    @available(*, deprecated, renamed: "init(stringValue:)", message: "Only string-based keys are supported!")
//    init?(intValue _: Int) {
//        return nil
//    }
//}
//
//
//private final class CodingKeysV1: CodingKeysBase, CodingKey, @unchecked Sendable {
//    
//}


extension StudyDefinition {
    private enum CodingKeysV0: String, CodingKey {
        case schemaVersion
        case studyRevision
        case metadata
        case components
        case schedule
    }
    
    public struct DecodingConfiguration {
        /// Whether the decoding operation should be allowed to perform trivial migrations when decoding definitions encoded using an older schema version
        public let allowTrivialSchemaMigrations: Bool
        
        public init(allowTrivialSchemaMigrations: Bool) {
            self.allowTrivialSchemaMigrations = allowTrivialSchemaMigrations
        }
    }
    
//    private struct CodingKey: Swift.CodingKey {
//        let stringValue: String
//        var intValue: Int? { nil }
//        
//        init(stringValue: String) {
//            self.stringValue = stringValue
//        }
//        
//        @available(*, deprecated, renamed: "init(stringValue:)", message: "Only string-based keys are supported!")
//        init?(intValue: Int) {
//            return nil
//        }
//        
//        static let schemaVersion = Self(stringValue: "schemaVersion")
//        
////        case studyRevision = "studyRevision"
////        case metadata = "metadata"
////        case components = "components"
////        case schedule = "schedule"
//    }
    
    public init(from decoder: any Decoder, configuration: DecodingConfiguration) throws {
        // TODO why not use made-up coding keys, to get just the schema, and then have the rest figured out dynamically?
        let container = try decoder.container(keyedBy: CodingKeysV0.self)
        let schemaVersion: SchemaVersion
        do {
            schemaVersion = try container.decode(SchemaVersion.self, forKey: .schemaVersion)
        } catch {
            if configuration.allowTrivialSchemaMigrations {
                schemaVersion = Self.schemaVersion
            } else {
                throw error
            }
        }
        guard schemaVersion == Self.schemaVersion else {
            fatalError()
        }
        switch schemaVersion {
        case .init(major: 0, minor: 0, patch: 1):
            do {
                studyRevision = try container.decode(UInt.self, forKey: .studyRevision)
            } catch DecodingError.keyNotFound where configuration.allowTrivialSchemaMigrations {
                studyRevision = 0
            } catch {
                throw error
            }
            metadata = try container.decode(Metadata.self, forKey: .metadata)
            components = try container.decode([Component].self, forKey: .components)
            schedule = try container.decode(Schedule.self, forKey: .schedule)
        default:
            throw DecodingError.dataCorrupted(.init(
                codingPath: [],
                debugDescription: "Unsupported schema version: got \(schemaVersion); current is \(Self.schemaVersion)"
            ))
        }
    }
    
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeysV0.self)
        try container.encode(Self.schemaVersion, forKey: .schemaVersion)
        try container.encode(studyRevision, forKey: .studyRevision)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(components, forKey: .components)
        try container.encode(schedule, forKey: .schedule)
    }
}
