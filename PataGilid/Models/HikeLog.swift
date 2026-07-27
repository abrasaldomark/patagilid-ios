//
//  HikeLog.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/27/26.
//

import Foundation
import FirebaseFirestore

/// Represents a user's climbing progress and check-in record stored in Firestore under `users/{userId}/hikeLogs/{logId}`.
struct HikeLog: Codable, Identifiable {
    @DocumentID var id: String?
    
    /// Unique identifier of the authenticated user (via Google Sign-In / Firebase Auth).
    var userId: String
    
    /// Foreign key reference linking to `Mountain.id`.
    var mountainId: String
    
    /// Date and time when the climb or activity occurred.
    var dateTime: Date
    
    /// Whether the hiker successfully reached the summit on this attempt.
    /// `false` implies the attempt was a turn-back (DNF).
    var didSummit: Bool
    
    /// Array of compressed image download URLs from Firebase Cloud Storage (Maximum 3 photos).
    var photoUrls: [String]
}
