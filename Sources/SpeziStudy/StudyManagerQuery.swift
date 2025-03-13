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


/// Performs a SwiftData query in the StudyManager's ModelContext
@propertyWrapper @MainActor
public struct StudyManagerQuery<T: PersistentModel>: DynamicProperty {
    public struct QueryState {
        public let fetchError: (any Error)?
    }
    
    @Environment(StudyManager.self) private var studyManager
    private let predicate: Predicate<T>?
    private let sortDescriptors: [SortDescriptor<T>]
    @State private var storage = Storage<T>()
    
    public init(_: T.Type = T.self, predicate: Predicate<T>? = nil, sortBy sortDescriptors: [SortDescriptor<T>] = []) {
        self.predicate = predicate
        self.sortDescriptors = sortDescriptors
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
                storage.fetchResult = .failure(error)
            }
        }
        let descriptor = FetchDescriptor<T>(predicate: predicate, sortBy: sortDescriptors)
        storage.fetchResult = Result { try studyManager.modelContext.fetch(descriptor) }
    }
    
    public var wrappedValue: [T] {
        storage.fetchResult.value ?? []
    }
    
    public var projectedValue: QueryState {
        QueryState(fetchError: storage.fetchResult.error)
    }
}


@Observable
private final class Storage<T> {
    var viewUpdate: UInt8 = 0
    @ObservationIgnored var cancellable: AnyCancellable?
    @ObservationIgnored var fetchResult: Result<[T], any Error> = .success([])
}


extension Result {
    var value: Success? {
        switch self {
        case .success(let value):
            value
        case .failure:
            nil
        }
    }
    
    var error: Failure? {
        switch self {
        case .success:
            nil
        case .failure(let error):
            error
        }
    }
}
