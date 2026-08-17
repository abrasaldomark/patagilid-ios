//
//  HikeLog.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/27/26.
//

import Foundation
import SwiftData
import FirebaseFirestore

/// Represents a user's climbing attempt stored in Firestore under `users/{userId}/hikeLogs/{logId}`.
@Model
final class HikeLog: Codable, Identifiable {
    @Attribute(.unique) var id: String
    
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
    var trailName: String = ""
    
    /// The type of route (Back Trail, Traverse, Circuit).
    var routeType: String = ""
    
    /// Optional exit trail name when traversing (e.g., "Salacafe Trail").
    var exitTrailName: String = ""
    
    /// Experienced climb difficulty rating for this log attempt (e.g., "7/9 (Major)").
    var trailDifficulty: String = ""
    
    /// Technical terrain classification encountered (e.g., "Class 3").
    var trailClass: String = ""
    
    /// Intermediate checkpoints for a circuit route.
    var waypoints: [String] = []
    
    // MARK: - Explicit Memberwise Init
    
    init(id: String = UUID().uuidString, userId: String, mountainId: String, dateTimeStart: Date, dateTimeEnd: Date,
         didSummit: Bool, photoUrls: [String],
         trailName: String = "", routeType: String = "", exitTrailName: String = "",
         trailDifficulty: String = "", trailClass: String = "", waypoints: [String] = []) {
        self.id = id
        self.userId = userId
        self.mountainId = mountainId
        self.dateTimeStart = dateTimeStart
        self.dateTimeEnd = dateTimeEnd
        self.didSummit = didSummit
        self.photoUrls = photoUrls
        self.trailName = trailName
        self.routeType = routeType
        self.exitTrailName = exitTrailName
        self.trailDifficulty = trailDifficulty
        self.trailClass = trailClass
        self.waypoints = waypoints
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case mountainId
        case dateTimeStart
        case dateTimeEnd
        case didSummit
        case photoUrls
        case trailName
        case routeType
        case exitTrailName
        case trailDifficulty
        case trailClass
        case waypoints
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        userId = try container.decode(String.self, forKey: .userId)
        mountainId = try container.decode(String.self, forKey: .mountainId)
        dateTimeStart = try container.decode(Date.self, forKey: .dateTimeStart)
        dateTimeEnd = try container.decode(Date.self, forKey: .dateTimeEnd)
        didSummit = try container.decode(Bool.self, forKey: .didSummit)
        photoUrls = try container.decodeIfPresent([String].self, forKey: .photoUrls) ?? []
        trailName = try container.decodeIfPresent(String.self, forKey: .trailName) ?? ""
        routeType = try container.decodeIfPresent(String.self, forKey: .routeType) ?? ""
        exitTrailName = try container.decodeIfPresent(String.self, forKey: .exitTrailName) ?? ""
        trailDifficulty = try container.decodeIfPresent(String.self, forKey: .trailDifficulty) ?? ""
        trailClass = try container.decodeIfPresent(String.self, forKey: .trailClass) ?? ""
        waypoints = try container.decodeIfPresent([String].self, forKey: .waypoints) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(mountainId, forKey: .mountainId)
        try container.encode(dateTimeStart, forKey: .dateTimeStart)
        try container.encode(dateTimeEnd, forKey: .dateTimeEnd)
        try container.encode(didSummit, forKey: .didSummit)
        try container.encode(photoUrls, forKey: .photoUrls)
        try container.encode(trailName, forKey: .trailName)
        try container.encode(routeType, forKey: .routeType)
        try container.encode(exitTrailName, forKey: .exitTrailName)
        try container.encode(trailDifficulty, forKey: .trailDifficulty)
        try container.encode(trailClass, forKey: .trailClass)
        try container.encode(waypoints, forKey: .waypoints)
    }
}
