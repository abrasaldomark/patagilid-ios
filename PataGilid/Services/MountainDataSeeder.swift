//
//  MountainDataSeeder.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/27/26.
//

import Foundation
import FirebaseFirestore

/// A dedicated service class responsible for seeding and populating Cloud Firestore (`mountains` collection)
/// with official reference data and engaging descriptions for 2,688 prominent and topographical peaks in the Philippines.
class MountainDataSeeder {
    static let shared = MountainDataSeeder()
    private let db = Firestore.firestore()
    
    /// Google Firebase Cloud endpoint hosting the authoritative Philippine mountain catalog.
    /// Points to Firebase Cloud Hosting (patagilid-a37cb.web.app) or Firebase Storage public download URL.
    private let firebaseCloudURLString = "https://patagilid-a37cb.web.app/philippine_mountains.json"
    
    private var cacheFileURL: URL {
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return cachesDirectory.appendingPathComponent("philippine_mountains_firebase_cache.json")
    }
    
    /// Loads the exhaustive catalog of Philippine mountains, prioritizing any freshly updated dataset downloaded from Firebase Cloud,
    /// falling back seamlessly to the default offline bundle if offline or on initial launch.
    var officialMountains: [Mountain] {
        let fileManager = FileManager.default
        let cachedURL = self.cacheFileURL
        
        // 1. Prioritize live updated JSON downloaded from Google Firebase Cloud CDN
        if fileManager.fileExists(atPath: cachedURL.path),
           let cachedData = try? Data(contentsOf: cachedURL),
           let downloadedMountains = try? JSONDecoder().decode([Mountain].self, from: cachedData),
           !downloadedMountains.isEmpty {
            return downloadedMountains
        }
        
        // 2. Fallback to default bundled dataset for guaranteed instant offline availability
        guard let url = Bundle.main.url(forResource: "philippine_mountains", withExtension: "json") else {
            print("❌ BUNDLE ERROR: philippine_mountains.json not found in Bundle.main! Please check 'Target Membership -> PataGilid' in Xcode's File Inspector.")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let mountains = try JSONDecoder().decode([Mountain].self, from: data)
            return mountains
        } catch {
            print("❌ JSON DECODING ERROR in philippine_mountains.json: \(error)")
            return []
        }
    }
    
    /// Asynchronously downloads the latest authoritative Philippine mountain JSON from Google Firebase Cloud CDN.
    /// Validates decoding before atomically replacing the local disk cache. Returns `true` if a newer dataset was applied.
    func fetchLatestCatalogFromFirebase() async -> Bool {
        guard let url = URL(string: firebaseCloudURLString) else { return false }
        do {
            print("🌐 Checking Google Firebase Cloud for mountain catalog updates...")
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("⚠️ Firebase Cloud response non-200. Maintaining existing offline catalog.")
                return false
            }
            
            // Verify the downloaded payload actually decodes cleanly into valid Mountain models
            let freshlyDecoded = try JSONDecoder().decode([Mountain].self, from: data)
            guard !freshlyDecoded.isEmpty else {
                print("⚠️ Downloaded JSON from Firebase Cloud was empty. Maintaining existing catalog.")
                return false
            }
            
            // Check if identical to what we already have cached on disk to avoid redundant UI reloads
            if let currentCachedData = try? Data(contentsOf: cacheFileURL), currentCachedData == data {
                print("✅ Firebase Cloud catalog matches cached version (\(freshlyDecoded.count) peaks). No UI update needed.")
                return false
            }
            
            // Write securely & atomically to disk
            try data.write(to: cacheFileURL, options: .atomic)
            print("🎉 Successfully downloaded and cached updated catalog of \(freshlyDecoded.count) mountains from Google Firebase Cloud!")
            return true
        } catch {
            print("🌐 Firebase Cloud sync paused (Offline or network unreachable): \(error.localizedDescription)")
            return false
        }
    }
}
