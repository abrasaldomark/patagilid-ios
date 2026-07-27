//
//  HikeLog.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/27/26.
//

import Foundation
import FirebaseFirestore

/// Represents a user's climbing attempt stored in Firestore under `users/{userId}/hikeLogs/{logId}`.
struct HikeLog: Codable, Identifiable {
    @DocumentID var id: String?
    
    /// Unique identifier of the authenticated user (via Google Sign-In / Firebase Auth).
    var userId: String
    
    /// Foreign key reference linking to `Mountain.id`.
    var mountainId: String
    
    /// Date and time when the climb started.
    var dateTimeStart: Date
    
    /// Date and time when the climb ended (summit or turn-back).
    var dateTimeEnd: Date
    
    /// Whether the hiker successfully reached the summit on this attempt.
    /// `false` implies the attempt was a turn-back.
    var didSummit: Bool
    
    /// Array of compressed image download URLs from Firebase Cloud Storage (Maximum 3 photos).
    var photoUrls: [String]
    
    // MARK: - Explicit Memberwise Init
    
    init(userId: String, mountainId: String, dateTimeStart: Date, dateTimeEnd: Date,
         didSummit: Bool, photoUrls: [String]) {
        self.userId = userId
        self.mountainId = mountainId
        self.dateTimeStart = dateTimeStart
        self.dateTimeEnd = dateTimeEnd
        self.didSummit = didSummit
        self.photoUrls = photoUrls
    }
}
