//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import FirebaseFirestore
import FirebaseStorage
import Foundation
import HealthKit
import PDFKit


extension StudyManager {
    /// The kind of consent document
    public enum ConsentDocumentContext {
        /// The user has consented to the app in general
        case generalAppUsage
        /// The user has consented to participation in the specified study.
        case studyEnrolment(StudyDefinition)
    }
    
    /// Imports a consent document into the study manager.
    public func importConsentDocument(_ pdf: PDFDocument, for context: ConsentDocumentContext) async throws {
        guard let accountId = await account.details?.accountId else {
            logger.error("Unable to get account id. not uploading consent form.")
            return
        }
        guard let pdfData = pdf.dataRepresentation() else {
            logger.error("Unable to get PDF data. not uploading consent form.")
            return
        }
        let storageRef = Storage.storage().reference(withPath: "users/\(accountId)/consent/\(UUID().uuidString).pdf")
        let metadata = StorageMetadata()
        metadata.contentType = "application/pdf"
        // do we have more metadata we want to add here?
        _ = try await storageRef.putDataAsync(pdfData, metadata: metadata)
    }
}
