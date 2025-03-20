//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import class ModelsR4.Questionnaire
import SpeziScheduler
import SpeziStudyDefinition
import SwiftData
import SwiftUI


// MARK: ActionCards

extension StudyManager {
    @MainActor
    public struct ActionCard: Identifiable, Hashable {
        @MainActor
        public enum Content: Hashable {
            case event(Event)
            case simple(SimpleContent)
            
            nonisolated public func hash(into hasher: inout Hasher) {
                switch self {
                case .event(let event):
                    hasher.combine(event.id)
                case .simple(let content):
                    hasher.combine(content.id)
                }
            }
            
            nonisolated public static func == (lhs: Self, rhs: Self) -> Bool {
                switch (lhs, rhs) {
                case let (.event(lhs), .event(rhs)):
                    lhs.id == rhs.id
                case let (.simple(lhs), .simple(rhs)):
                    lhs == rhs
                case (.event, .simple), (.simple, .event):
                    false
                }
            }
        }
        
        @MainActor
        public struct SimpleContent: Identifiable, Hashable {
            public let id: String
            public let symbol: String?
            public let title: String
            public let message: String
            
            public init(id: String, symbol: String?, title: String, message: String) {
                self.id = id
                self.symbol = symbol
                self.title = title
                self.message = message
            }
        }
        
        public let content: Content
        public let action: Action
        
        nonisolated public var id: AnyHashable {
            switch content {
            case .simple(let content):
                return content.id
            case .event(let event):
                return event.id
            }
        }
        
        @MainActor
        public enum Action: Hashable, Codable {
            // TODO
            case listAllAvailableStudies
            case enrollInStudy(StudyDefinition)
            case presentInformationalStudyComponent(StudyDefinition.InformationalComponent)
            case answerQuestionnaire(Questionnaire, spcId: PersistentIdentifier)
        }
        
        
        fileprivate static let enrollInStudy = Self(content: .simple(.init(
            id: "enroll-in-study",
            symbol: "list.triangle",
            title: "Enroll in a Study",
            message: "Participate in one or multiple studies, to share data with scientific researchers, receive actionable advice on how you can improve and maintain your personal health, and help out others in the process." // swiftlint:disable:this line_length
    //                trailingAccessory: .disclosureIndicator
        )), action: .listAllAvailableStudies)
    }
}
