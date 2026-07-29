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
    
    /// Array of compressed image download URLs from Firebase Cloud Storage or Google Drive (Maximum 3 photos).
    var photoUrls: [String]
    
    /// Sanitizes photo URLs, automatically converting Google Drive web preview links into direct downloadable image URLs for AsyncImage.
    var cleanPhotoUrls: [String] {
        return photoUrls.map { url in
            if url.contains("drive.google.com/file/d/") {
                let components = url.components(separatedBy: "file/d/")
                if components.count > 1 {
                    let idPart = components[1].components(separatedBy: "/")[0].components(separatedBy: "?")[0]
                    return "https://drive.google.com/uc?id=\(idPart)&export=view"
                }
            }
            return url
        }
    }
    
    /// Optional custom trail or traverse route taken (e.g., "Kule Trail"). For a traverse, this is the Entry Trail.
    var trailName: String?
    
    /// Whether the attempt was a traverse route (entry and exit points on different trails).
    var isTraverse: Bool?
    
    /// Optional exit trail name when traversing (e.g., "Salacafe Trail").
    var exitTrailName: String?
    
    /// Experienced climb difficulty rating for this log attempt (e.g., "7/9 (Major)").
    var trailDifficulty: String?
    
    /// Technical terrain classification encountered (e.g., "Class 3").
    var trailClass: String?
    
    // MARK: - Explicit Memberwise Init
    
    init(userId: String, mountainId: String, dateTimeStart: Date, dateTimeEnd: Date,
         didSummit: Bool, photoUrls: [String],
         trailName: String? = nil, isTraverse: Bool? = nil, exitTrailName: String? = nil,
         trailDifficulty: String? = nil, trailClass: String? = nil) {
        self.userId = userId
        self.mountainId = mountainId
        self.dateTimeStart = dateTimeStart
        self.dateTimeEnd = dateTimeEnd
        self.didSummit = didSummit
        self.photoUrls = photoUrls
        self.trailName = trailName
        self.isTraverse = isTraverse
        self.exitTrailName = exitTrailName
        self.trailDifficulty = trailDifficulty
        self.trailClass = trailClass
    }
}
