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
    
    // MARK: - 48-Hour Sync Throttling & Caching
    private let lastSyncTimestampKey = "lastMountainCatalogSyncTimestamp"
    private let lastETagKey = "lastMountainCatalogETag"
    private let syncThrottleInterval: TimeInterval = 48 * 60 * 60 // 48 Hours in seconds
    
    private func shouldPerformCatalogSync(force: Bool) -> Bool {
        if force { return true }
        let lastSync = UserDefaults.standard.double(forKey: lastSyncTimestampKey)
        let now = Date().timeIntervalSince1970
        // Trigger if last sync was more than 48 hours ago, or if timestamp has not been recorded yet (0.0)
        return (now - lastSync) >= syncThrottleInterval || lastSync == 0
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
    /// Uses a 48-hour timestamp throttle and HTTP ETag validation to prevent unnecessary bandwidth consumption or network timeouts in remote hiking areas.
    /// Validates decoding before atomically replacing the local disk cache. Returns `true` if a newer dataset was applied.
    func fetchLatestCatalogFromFirebase(force: Bool = false) async -> Bool {
        guard let url = URL(string: firebaseCloudURLString) else { return false }
        
        guard shouldPerformCatalogSync(force: force) else {
            let lastSync = Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: lastSyncTimestampKey))
            print("⏸️ Catalog sync throttled (Last checked on \(lastSync.formatted(date: .abbreviated, time: .shortened))). Next check available after 48 hours.")
            return false
        }
        
        do {
            print("🌐 Checking Google Firebase Cloud for mountain catalog updates...")
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15.0)
            if let savedETag = UserDefaults.standard.string(forKey: lastETagKey),
               FileManager.default.fileExists(atPath: cacheFileURL.path) {
                request.setValue(savedETag, forHTTPHeaderField: "If-None-Match")
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                print("⚠️ Firebase Cloud response invalid. Maintaining existing offline catalog.")
                return false
            }
            
            // 304 Not Modified means the catalog on Firebase is identical to our disk cache
            if httpResponse.statusCode == 304 {
                print("⚡️ Firebase Cloud returned 304 Not Modified. Existing offline catalog is completely up-to-date!")
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastSyncTimestampKey)
                return false
            }
            
            guard httpResponse.statusCode == 200 else {
                print("⚠️ Firebase Cloud response non-200 (\(httpResponse.statusCode)). Maintaining existing offline catalog.")
                return false
            }
            
            // Verify the downloaded payload actually decodes cleanly into valid Mountain models
            let freshlyDecoded = try JSONDecoder().decode([Mountain].self, from: data)
            guard !freshlyDecoded.isEmpty else {
                print("⚠️ Downloaded JSON from Firebase Cloud was empty. Maintaining existing catalog.")
                return false
            }
            
            // Save updated timestamp and ETag
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastSyncTimestampKey)
            if let newETag = httpResponse.allHeaderFields["Etag"] as? String ?? httpResponse.allHeaderFields["ETag"] as? String {
                UserDefaults.standard.set(newETag, forKey: lastETagKey)
            }
            
            // Check if identical to what we already have cached on disk to avoid redundant UI reloads
            if let currentCachedData = try? Data(contentsOf: cacheFileURL), currentCachedData == data {
                print("✅ Firebase Cloud catalog content matches cached version (\(freshlyDecoded.count) peaks). No UI reload needed.")
                return false
            }
            
            // Write securely & atomically to disk
            try data.write(to: cacheFileURL, options: .atomic)
            print("🎉 Successfully downloaded and cached updated catalog of \(freshlyDecoded.count) mountains from Google Firebase Cloud!")
            return true
        } catch {
            print("🌐 Firebase Cloud sync deferred (Offline, weak cellular signal, or network unreachable): \(error.localizedDescription)")
            return false
        }
    }
}
