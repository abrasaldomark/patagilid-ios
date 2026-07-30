//
//  Mountain.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/27/26.
//

import Foundation
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

/// Represents a Philippine mountain peak reference entity stored in Cloud Firestore (`mountains` collection).
struct Mountain: Identifiable, Hashable {
    var id: String
    
    /// Display name of the peak (e.g., "Mt. Pulag", "Mt. Guiting-Guiting").
    var name: String
    
    /// Descriptive overview of the mountain, hiking features, flora/fauna, and significance.
    var description: String
    
    /// Elevation in Meters Above Sea Level (MASL), used for ordering from highest to lowest.
    var elevationMASL: Int
    
    /// Geographic coordinates in Decimal Degrees (DD) for rendering pins on Google Maps and calculations.
    var latitude: Double
    var longitude: Double
    
    /// Administrative region classification (e.g., "CAR", "CALABARZON", "SOCCSKSARGEN").
    var region: String
    
    /// Major island classification (Luzon, Visayas, or Mindanao).
    var islandGroup: IslandGroup
    
    /// Philippine mountaineering difficulty scale (e.g., "3/9 (Minor)", "6/9 (Major)", "9/9 (Major)").
    var difficultyLevel: String
    
    /// Technical terrain grading (e.g., "Class 1-2", "Class 3", "Class 4").
    var trailClass: String
    
    // MARK: - Community Submission Metadata
    
    /// Approval status for crowdsourced local mountains.
    /// `false` for pending user-submitted peaks; `nil` or `true` for official catalog peaks.
    var isApproved: Bool?
    
    /// Firebase Auth User ID of the explorer who contributed this local peak.
    var contributorId: String?
    
    /// Contributor email address for administrative moderation context.
    var contributorEmail: String?
    
    /// Helper property determining if this mountain should be displayed in the global public directory.
    var isPubliclyApproved: Bool {
        return isApproved ?? true
    }
    
    // MARK: - Coordinate Formatting Helpers
    
    /// Returns the latitude formatted as Degrees, Minutes, Seconds (DMS), e.g., "6° 59' 15\" N".
    var formattedLatitudeDMS: String {
        return Mountain.toDMS(degree: latitude, isLatitude: true)
    }
    
    /// Returns the longitude formatted as Degrees, Minutes, Seconds (DMS), e.g., "125° 16' 16\" E".
    var formattedLongitudeDMS: String {
        return Mountain.toDMS(degree: longitude, isLatitude: false)
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

// MARK: - Codable Conformance (DMS & Decimal Degrees Compatibility)
extension Mountain: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, description, elevationMASL
        case latitude, longitude, region, islandGroup
        case difficultyLevel, trailClass
        case isApproved, contributorId, contributorEmail
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decode(String.self, forKey: .description)
        self.elevationMASL = try container.decode(Int.self, forKey: .elevationMASL)
        self.region = try container.decode(String.self, forKey: .region)
        self.islandGroup = try container.decode(IslandGroup.self, forKey: .islandGroup)
        self.difficultyLevel = try container.decode(String.self, forKey: .difficultyLevel)
        self.trailClass = try container.decode(String.self, forKey: .trailClass)
        
        self.isApproved = try container.decodeIfPresent(Bool.self, forKey: .isApproved)
        self.contributorId = try container.decodeIfPresent(String.self, forKey: .contributorId)
        self.contributorEmail = try container.decodeIfPresent(String.self, forKey: .contributorEmail)
        
        self.latitude = try Mountain.decodeCoordinate(from: container, forKey: .latitude, isLatitude: true)
        self.longitude = try Mountain.decodeCoordinate(from: container, forKey: .longitude, isLatitude: false)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(elevationMASL, forKey: .elevationMASL)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encode(region, forKey: .region)
        try container.encode(islandGroup, forKey: .islandGroup)
        try container.encode(difficultyLevel, forKey: .difficultyLevel)
        try container.encode(trailClass, forKey: .trailClass)
        try container.encodeIfPresent(isApproved, forKey: .isApproved)
        try container.encodeIfPresent(contributorId, forKey: .contributorId)
        try container.encodeIfPresent(contributorEmail, forKey: .contributorEmail)
    }
    
    private static func decodeCoordinate(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys,
        isLatitude: Bool
    ) throws -> Double {
        if let doubleVal = try? container.decode(Double.self, forKey: key) {
            return doubleVal
        }
        if let stringVal = try? container.decode(String.self, forKey: key) {
            if let parsedDouble = Double(stringVal) {
                return parsedDouble
            }
            if let dmsDouble = parseDMS(stringVal, isLatitude: isLatitude) {
                return dmsDouble
            }
        }
        throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "Unable to parse coordinate value as Double or DMS String.")
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
