//
//  CoordinateSubmission.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 8/2/26.
//

import Foundation
import FirebaseFirestore

/// A crowdsourced GPS coordinate contribution awaiting admin review before calibrating official mountain entries.
struct CoordinateSubmission: Codable, Identifiable {
    var id: String
    var mountainId: String
    var mountainName: String
    var region: String
    var latitude: Double
    var longitude: Double
    var contributorEmail: String?
    var submittedAt: Date
    var status: String // "pending", "approved", "rejected"
}
