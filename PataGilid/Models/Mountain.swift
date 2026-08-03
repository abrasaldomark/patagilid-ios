//
//  Mountain.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/27/26.
//

import Foundation
import SwiftData
import FirebaseFirestore

/// Major island groups in the Philippines for geographical grouping and filtering.
enum IslandGroup: String, Codable, CaseIterable, Identifiable {
    case luzon = "Luzon"
    case visayas = "Visayas"
    case mindanao = "Mindanao"
    
    var id: String { rawValue }
    
    var systemImageName: String? {
        return nil
    }
    
    var assetImageName: String? {
        switch self {
        case .luzon: return "luzon_icon"
        case .visayas: return "visayas_icon"
        case .mindanao: return "mindanao_icon"
        }
    }
}

/// Represents a Philippine mountain peak reference entity persisted locally via SwiftData and synchronized with Cloud Firestore (`mountains` collection).
@Model
final class Mountain: Identifiable, Hashable {
    @Attribute(.unique) var id: String
    
    /// Display name of the peak (e.g., "Mt. Pulag", "Mt. Guiting-Guiting").
    var name: String
    
    /// Descriptive overview of the mountain, hiking features, flora/fauna, and significance.
    var descriptionText: String
    
    /// Elevation in Meters Above Sea Level (MASL), used for ordering from highest to lowest.
    var elevationMASL: Int
    
    /// Geographic coordinates in Decimal Degrees (DD). Optional (`nil`) if awaiting accurate community GPS verification!
    var latitude: Double?
    var longitude: Double?
    
    /// Administrative region classification (e.g., "CAR", "CALABARZON", "SOCCSKSARGEN").
    var region: String
    
    /// Major island classification (Luzon, Visayas, or Mindanao).
    var islandGroup: IslandGroup
    
    /// Philippine mountaineering difficulty scale (e.g., "3/9 (Minor)", "6/9 (Major)", "9/9 (Major)").
    var difficultyLevel: String
    
    /// Technical terrain grading (e.g., "Class 1-2", "Class 3", "Class 4").
    var trailClass: String
    
    // MARK: - Community Submission & Moderation Metadata
    
    /// Approval status for crowdsourced local mountains.
    /// `false` for pending user-submitted peaks; `nil` or `true` for official catalog peaks.
    var isApproved: Bool?
    
    /// Firebase Auth User ID of the explorer who contributed this local peak.
    var contributorId: String?
    
    /// Contributor email address for administrative moderation context.
    var contributorEmail: String?
    
    // MARK: - Delta-Sync & Crowdsourced GPS Verification Metadata
    
    /// Timestamp indicating when this peak record or its GPS coordinates were last calibrated in Firestore.
    var updatedAt: Date
    
    /// True if real hikers have verified the exact GPS summit location on the mountain.
    var isVerifiedByCommunity: Bool
    
    /// Total number of hikers who have contributed or affirmed these GPS coordinates.
    var communityVerifications: Int
    
    /// Helper property determining if this mountain should be displayed in the global public directory.
    var isPubliclyApproved: Bool {
        return isApproved ?? true
    }
    
    init(
        id: String,
        name: String,
        description: String,
        elevationMASL: Int,
        latitude: Double? = nil,
        longitude: Double? = nil,
        region: String,
        islandGroup: IslandGroup,
        difficultyLevel: String,
        trailClass: String,
        isApproved: Bool? = nil,
        contributorId: String? = nil,
        contributorEmail: String? = nil,
        updatedAt: Date = Date(),
        isVerifiedByCommunity: Bool = false,
        communityVerifications: Int = 0
    ) {
        self.id = id
        self.name = name
        self.descriptionText = description
        self.elevationMASL = elevationMASL
        self.latitude = latitude
        self.longitude = longitude
        self.region = region
        self.islandGroup = islandGroup
        self.difficultyLevel = difficultyLevel
        self.trailClass = trailClass
        self.isApproved = isApproved
        self.contributorId = contributorId
        self.contributorEmail = contributorEmail
        self.updatedAt = updatedAt
        self.isVerifiedByCommunity = isVerifiedByCommunity
        self.communityVerifications = communityVerifications
    }
    
    // MARK: - Hashable & Equatable (By ID)
    static func == (lhs: Mountain, rhs: Mountain) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Coordinate Formatting Helpers
    
    /// Returns the latitude formatted as Degrees, Minutes, Seconds (DMS), or a friendly placeholder if unmapped.
    var formattedLatitudeDMS: String {
        guard let lat = latitude else { return "Coordinates needed" }
        return Mountain.toDMS(degree: lat, isLatitude: true)
    }
    
    /// Returns the longitude formatted as Degrees, Minutes, Seconds (DMS), or a friendly placeholder if unmapped.
    var formattedLongitudeDMS: String {
        guard let lon = longitude else { return "Coordinates needed" }
        return Mountain.toDMS(degree: lon, isLatitude: false)
    }
    
    /// Converts a decimal degree coordinate into a standardized DMS string format.
    static func toDMS(degree: Double, isLatitude: Bool) -> String {
        let direction = isLatitude ? (degree >= 0 ? "N" : "S") : (degree >= 0 ? "E" : "W")
        
        let val = abs(degree)
        var d = Int(val)
        let rem = (val - Double(d)) * 60.0
        var m = Int(rem)
        var s = (rem - Double(m)) * 60.0
        
        s = (s * 10.0).rounded() / 10.0
        if s >= 60.0 {
            s = 0.0
            m += 1
        }
        if m >= 60 {
            m = 0
            d += 1
        }
        
        let secondsStr = s.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(s)) : String(format: "%.1f", s)
        return "\(d)° \(m)' \(secondsStr)\" \(direction)"
    }
}

// MARK: - Codable Conformance (DMS & Decimal Degrees & SwiftData Compatibility)
extension Mountain: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, description, elevationMASL
        case latitude, longitude, region, islandGroup
        case difficultyLevel, trailClass
        case isApproved, contributorId, contributorEmail
        case updatedAt, isVerifiedByCommunity, communityVerifications
    }
    
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let id = try container.decode(String.self, forKey: .id)
        let name = try container.decode(String.self, forKey: .name)
        let description = try container.decode(String.self, forKey: .description)
        let elevationMASL = try container.decode(Int.self, forKey: .elevationMASL)
        let region = try container.decode(String.self, forKey: .region)
        let islandGroup = try container.decode(IslandGroup.self, forKey: .islandGroup)
        let difficultyLevel = try container.decode(String.self, forKey: .difficultyLevel)
        let trailClass = try container.decode(String.self, forKey: .trailClass)
        
        let isApproved = try container.decodeIfPresent(Bool.self, forKey: .isApproved)
        let contributorId = try container.decodeIfPresent(String.self, forKey: .contributorId)
        let contributorEmail = try container.decodeIfPresent(String.self, forKey: .contributorEmail)
        
        let latitude = try? Mountain.decodeCoordinate(from: container, forKey: .latitude, isLatitude: true)
        let longitude = try? Mountain.decodeCoordinate(from: container, forKey: .longitude, isLatitude: false)
        
        let updatedAt: Date
        if let dateVal = try? container.decodeIfPresent(Date.self, forKey: .updatedAt) {
            updatedAt = dateVal
        } else if let timeInterval = try? container.decodeIfPresent(TimeInterval.self, forKey: .updatedAt) {
            updatedAt = Date(timeIntervalSince1970: timeInterval)
        } else {
            updatedAt = Date()
        }
        
        let isVerifiedByCommunity = try container.decodeIfPresent(Bool.self, forKey: .isVerifiedByCommunity) ?? false
        let communityVerifications = try container.decodeIfPresent(Int.self, forKey: .communityVerifications) ?? 0
        
        self.init(
            id: id,
            name: name,
            description: description,
            elevationMASL: elevationMASL,
            latitude: latitude,
            longitude: longitude,
            region: region,
            islandGroup: islandGroup,
            difficultyLevel: difficultyLevel,
            trailClass: trailClass,
            isApproved: isApproved,
            contributorId: contributorId,
            contributorEmail: contributorEmail,
            updatedAt: updatedAt,
            isVerifiedByCommunity: isVerifiedByCommunity,
            communityVerifications: communityVerifications
        )
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(descriptionText, forKey: .description)
        try container.encode(elevationMASL, forKey: .elevationMASL)
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
        try container.encode(region, forKey: .region)
        try container.encode(islandGroup, forKey: .islandGroup)
        try container.encode(difficultyLevel, forKey: .difficultyLevel)
        try container.encode(trailClass, forKey: .trailClass)
        try container.encodeIfPresent(isApproved, forKey: .isApproved)
        try container.encodeIfPresent(contributorId, forKey: .contributorId)
        try container.encodeIfPresent(contributorEmail, forKey: .contributorEmail)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(isVerifiedByCommunity, forKey: .isVerifiedByCommunity)
        try container.encode(communityVerifications, forKey: .communityVerifications)
    }
    
    private static func decodeCoordinate(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys,
        isLatitude: Bool
    ) throws -> Double? {
        if let doubleVal = try? container.decodeIfPresent(Double.self, forKey: key) {
            return doubleVal
        }
        if let stringVal = try? container.decodeIfPresent(String.self, forKey: key) {
            if let parsedDouble = Double(stringVal) {
                return parsedDouble
            }
            if let dmsDouble = parseDMS(stringVal, isLatitude: isLatitude) {
                return dmsDouble
            }
        }
        return nil
    }
    
    /// Parses a DMS coordinate string (e.g., "6° 59' 15\" N") into Decimal Degrees.
    static func parseDMS(_ dms: String, isLatitude: Bool) -> Double? {
        let cleaned = dms.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        var sign: Double = 1.0
        if cleaned.contains("S") || cleaned.contains("SOUTH") || cleaned.contains("W") || cleaned.contains("WEST") {
            sign = -1.0
        }
        
        let pattern = #"(\d+(?:\.\d+)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        let results = regex.matches(in: cleaned, options: [], range: NSRange(cleaned.startIndex..., in: cleaned))
        let numbers: [Double] = results.compactMap { match in
            if let range = Range(match.range, in: cleaned) {
                return Double(cleaned[range])
            }
            return nil
        }
        
        guard !numbers.isEmpty else { return nil }
        
        let degrees = numbers.count > 0 ? numbers[0] : 0.0
        let minutes = numbers.count > 1 ? numbers[1] : 0.0
        let seconds = numbers.count > 2 ? numbers[2] : 0.0
        
        return (degrees + (minutes / 60.0) + (seconds / 3600.0)) * sign
    }
}
