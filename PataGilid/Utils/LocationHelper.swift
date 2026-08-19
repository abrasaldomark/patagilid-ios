//
//  LocationHelper.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 8/9/26.
//

import Foundation
import CoreLocation
import FirebaseCore

class LocationHelper {
    
    static let canonicalRegions: [String] = [
        "NCR – National Capital Region (Metro Manila)",
        "CAR – Cordillera Administrative Region",
        "Region 1 – Ilocos Region",
        "Region 2 – Cagayan Valley",
        "Region 3 – Central Luzon",
        "Region 4-A – CALABARZON",
        "MIMAROPA – Southwestern Tagalog Region",
        "Region 5 – Bicol Region",
        "Region 6 – Western Visayas",
        "NIR – Negros Island Region",
        "Region 7 – Central Visayas",
        "Region 8 – Eastern Visayas",
        "Region 9 – Zamboanga Peninsula",
        "Region 10 – Northern Mindanao",
        "Region 11 – Davao Region",
        "Region 12 – SOCCSKSARGEN",
        "Region 13 – Caraga",
        "BARMM – Bangsamoro Autonomous Region in Muslim Mindanao"
    ]
    
    /// Reverse geocodes the given coordinate and maps it to PataGilid's Island Group and Region.
    /// - Parameters:
    ///   - coordinate: The coordinate to reverse geocode.
    ///   - completion: A closure called with the mapped Region and Island Group. Nil if it fails or is outside the Philippines.
    static func reverseGeocode(coordinate: CLLocationCoordinate2D, completion: @escaping (String?, String?, IslandGroup?) -> Void) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            guard error == nil, let placemark = placemarks?.first else {
                completion(nil, nil, nil)
                return
            }
            
            // Check if the location is in the Philippines
            if let countryCode = placemark.isoCountryCode, countryCode != "PH" {
                completion(nil, nil, nil)
                return
            }
            
            let name = placemark.name
            
            // Try to map based on administrativeArea (Region/Province)
            let adminArea = placemark.administrativeArea ?? ""
            let subAdminArea = placemark.subAdministrativeArea ?? ""
            let locality = placemark.locality ?? ""
            
            let (region, islandGroup) = mapToInternalRegion(adminArea: adminArea, subAdminArea: subAdminArea, locality: locality)
            completion(name, region, islandGroup)
        }
    }
    
    static func fetchElevation(coordinate: CLLocationCoordinate2D, completion: @escaping (Double?) -> Void) {
        guard let apiKey = FirebaseApp.app()?.options.apiKey else {
            completion(nil)
            return
        }
        
        let urlString = "https://maps.googleapis.com/maps/api/elevation/json?locations=\(coordinate.latitude),\(coordinate.longitude)&key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let status = json["status"] as? String, status == "OK",
                   let results = json["results"] as? [[String: Any]],
                   let firstResult = results.first,
                   let elevation = firstResult["elevation"] as? Double {
                    completion(elevation)
                } else {
                    completion(nil)
                }
            } catch {
                completion(nil)
            }
        }.resume()
    }
    
    static func mapToInternalRegion(adminArea: String, subAdminArea: String, locality: String) -> (String?, IslandGroup?) {
        let primarySearchString = "\(adminArea) \(subAdminArea)".lowercased()
        let fallbackSearchString = "\(adminArea) \(subAdminArea) \(locality)".lowercased()
        
        let match: (String) -> (String?, IslandGroup?) = { searchString in
            // LUZON
            if searchString.contains("ilocos") || searchString.contains("pangasinan") || searchString.contains("la union") {
                return ("Region 1 – Ilocos Region", .luzon)
            } else if searchString.contains("cagayan") || searchString.contains("isabela") || searchString.contains("nueva vizcaya") || searchString.contains("quirino") || searchString.contains("batanes") {
                return ("Region 2 – Cagayan Valley", .luzon)
            } else if searchString.contains("central luzon") || searchString.contains("aurora") || searchString.contains("bataan") || searchString.contains("bulacan") || searchString.contains("nueva ecija") || searchString.contains("pampanga") || searchString.contains("tarlac") || searchString.contains("zambales") {
                return ("Region 3 – Central Luzon", .luzon)
            } else if searchString.contains("calabarzon") || searchString.contains("batangas") || searchString.contains("cavite") || searchString.contains("laguna") || searchString.contains("quezon") || searchString.contains("rizal") {
                return ("Region 4-A – CALABARZON", .luzon)
            } else if searchString.contains("mimaropa") || searchString.contains("marinduque") || searchString.contains("occidental mindoro") || searchString.contains("oriental mindoro") || searchString.contains("palawan") || searchString.contains("romblon") {
                return ("MIMAROPA – Southwestern Tagalog Region", .luzon)
            } else if searchString.contains("bicol") || searchString.contains("albay") || searchString.contains("camarines") || searchString.contains("catanduanes") || searchString.contains("masbate") || searchString.contains("sorsogon") {
                return ("Region 5 – Bicol Region", .luzon)
            } else if searchString.contains("cordillera") || searchString.contains("abra") || searchString.contains("apayao") || searchString.contains("benguet") || searchString.contains("ifugao") || searchString.contains("kalinga") || searchString.contains("mountain province") || searchString.contains("car") {
                return ("CAR – Cordillera Administrative Region", .luzon)
            } else if searchString.contains("ncr") || searchString.contains("national capital") || searchString.contains("manila") {
                return ("NCR – National Capital Region (Metro Manila)", .luzon)
            }
            
            // VISAYAS
            else if searchString.contains("western visayas") || searchString.contains("aklan") || searchString.contains("antique") || searchString.contains("capiz") || searchString.contains("guimaras") || searchString.contains("iloilo") {
                return ("Region 6 – Western Visayas", .visayas)
            } else if searchString.contains("negros island") || searchString.contains("negros occidental") || searchString.contains("negros oriental") || searchString.contains("siquijor") || searchString.contains("nir") {
                return ("NIR – Negros Island Region", .visayas)
            } else if searchString.contains("central visayas") || searchString.contains("bohol") || searchString.contains("cebu") {
                return ("Region 7 – Central Visayas", .visayas)
            } else if searchString.contains("eastern visayas") || searchString.contains("biliran") || searchString.contains("leyte") || searchString.contains("samar") {
                return ("Region 8 – Eastern Visayas", .visayas)
            }
            
            // MINDANAO
            else if searchString.contains("zamboanga") {
                return ("Region 9 – Zamboanga Peninsula", .mindanao)
            } else if searchString.contains("northern mindanao") || searchString.contains("bukidnon") || searchString.contains("camiguin") || searchString.contains("lanao del norte") || searchString.contains("misamis") {
                return ("Region 10 – Northern Mindanao", .mindanao)
            } else if searchString.contains("davao") || searchString.contains("compostela") {
                return ("Region 11 – Davao Region", .mindanao)
            } else if searchString.contains("soccsksargen") || searchString.contains("cotabato") || searchString.contains("sarangani") || searchString.contains("sultan kudarat") {
                return ("Region 12 – SOCCSKSARGEN", .mindanao)
            } else if searchString.contains("caraga") || searchString.contains("agusan") || searchString.contains("dinagat") || searchString.contains("surigao") {
                return ("Region 13 – Caraga", .mindanao)
            } else if searchString.contains("barmm") || searchString.contains("bangsamoro") || searchString.contains("basilan") || searchString.contains("lanao del sur") || searchString.contains("maguindanao") || searchString.contains("sulu") || searchString.contains("tawi-tawi") {
                return ("BARMM – Bangsamoro Autonomous Region in Muslim Mindanao", .mindanao)
            }
            
            return (nil, nil)
        }
        
        let (region, group) = match(primarySearchString)
        if region != nil {
            return (region, group)
        }
        
        return match(fallbackSearchString)
    }
}

extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
