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
    
    /// Loads the exhaustive catalog of 2,688 Philippine mountain summits from the bundled JSON dataset.
    var officialMountains: [Mountain] {
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
    
    /// Asynchronous method to write or update all 2,688 official Philippine mountains into Cloud Firestore's `mountains` collection.
    /// To respect Firestore write limits and maximize network efficiency, it processes documents in automated Firestore write batches.
    func seedMountainsIfNeeded() async throws {
        let mountains = officialMountains
        guard !mountains.isEmpty else {
            print("⚠️ No mountains loaded from bundle to seed.")
            return
        }
        
        print("⏳ Starting batch seeding of \(mountains.count) mountains into Firestore...")
        let collection = db.collection("mountains")
        
        // Firestore allows up to 500 writes per batch. We chunk by 450 for fast, reliable syncing!
        let chunkSize = 450
        var successCount = 0
        
        for chunk in mountains.chunked(into: chunkSize) {
            let batch = db.batch()
            for mountain in chunk {
                let documentId = mountain.id
                let docRef = collection.document(documentId)
                try batch.setData(from: mountain, forDocument: docRef, merge: true)
            }
            try await batch.commit()
            successCount += chunk.count
            print("✅ Committed batch of \(chunk.count) mountains (Total synced: \(successCount)/\(mountains.count)).")
        }
        
        print("🎉 🎉 Successfully seeded ALL \(successCount) Philippine mountains into Cloud Firestore!")
    }
}

// MARK: - Array Chunking Helper for Firestore Batch Writes
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
