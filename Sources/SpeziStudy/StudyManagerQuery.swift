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


@propertyWrapper @MainActor
public struct StudyManagerQuery<T: PersistentModel>: DynamicProperty {
    public struct _State {
        let predicate: Predicate<T>?
        let sortDescriptors: [SortDescriptor<T>]
        fileprivate(set) var fetchError: (any Error)?
    }
    
    @Environment(StudyManager.self) private var studyManager
    @State private var storage = Storage<T>()
    @State private var state: _State
    
    public init(_: T.Type = T.self, predicate: Predicate<T>? = nil, sortBy sortDescriptors: [SortDescriptor<T>] = []) {
        state = .init(predicate: predicate, sortDescriptors: sortDescriptors) // TODO allow further customoization!
    }
    
    nonisolated public func update() {
        MainActor.assumeIsolated {
            doUpdate()
        }
    }
    
    private func doUpdate() {
        if storage.cancellable == nil {
            do {
                storage.cancellable = try studyManager.sinkDidSavePublisher { [$storage] _ in
                    $storage.wrappedValue.viewUpdate &+= 1
                }
            } catch {
                state.fetchError = error
            }
        }
        do {
            let descriptor = FetchDescriptor<T>.init(predicate: state.predicate, sortBy: state.sortDescriptors)
            storage.results = try studyManager.modelContext.fetch(descriptor)
            state.fetchError = nil
        } catch {
            state.fetchError = error
        }
    }
    
    public var wrappedValue: [T] {
        storage.results
    }
    
    public var projectedValue: _State {
        state
    }
}


@Observable
private final class Storage<T> {
    var viewUpdate: UInt8 = 0
    var cancellable: AnyCancellable?
    var results: [T] = []
}


