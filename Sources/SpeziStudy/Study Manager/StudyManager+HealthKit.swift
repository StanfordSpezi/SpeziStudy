//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import FirebaseFirestore
import Foundation
import HealthKit


extension StudyManager {
    /// Uploads a new HealthKit sample to the Firestore
    public func handleNewHealthSample(_ sample: HKSample) async {
        // IDEA instead of performing the upload right in here, maybe add it to a queue and
        // have a background task that just goes over the queue until its empty?
        do {
            try await healthKitDocument(id: sample.uuid)
                .setData(from: sample.resource)
        } catch {
            logger.error("Error saving HealthKit sample to Firebase: \(error)")
            // maybe queue sample for later retry?
            // (probably not needed, since firebase already seems to be doing this for us...)
        }
    }
    
    /// Propagates a deleted HealthKit sample to the Firestore
    public func handleDeletedHealthObject(_ object: HKDeletedObject) async {
        do {
            try await healthKitDocument(id: object.uuid).delete()
        } catch {
            logger.error("Error saving HealthKit sample to Firebase: \(error)")
            // (probably not needed, since firebase already seems to be doing this for us...)
        }
    }
    
    private func healthKitDocument(id uuid: UUID) async throws -> DocumentReference {
        try await firebaseConfiguration.userDocumentReference
            .collection("HealthKitObservations") // Add all HealthKit sources in a /HealthKit collection.
            .document(uuid.uuidString) // Set the document identifier to the UUID of the document.
    }
}
