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
}

/// Represents a Philippine mountain peak reference entity stored in Cloud Firestore (`mountains` collection).
struct Mountain: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    
    /// Display name of the peak (e.g., "Mt. Pulag", "Mt. Guiting-Guiting").
    var name: String
    
    /// Descriptive overview of the mountain, hiking features, flora/fauna, and significance.
    var description: String
    
    /// Elevation in Meters Above Sea Level (MASL), used for ordering from highest to lowest.
    var elevationMASL: Int
    
    /// Geographic coordinates for rendering pins on Google Maps.
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
}
