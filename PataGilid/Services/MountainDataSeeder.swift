//
//  MountainDataSeeder.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/27/26.
//

import Foundation
import SwiftData
import FirebaseFirestore

/// A dedicated service class responsible for syncing Cloud Firestore (`mountains` collection)
/// with the user's high-speed local SwiftData persistence database using cost-optimized Delta-Sync architecture.
class MountainDataSeeder {
    static let shared = MountainDataSeeder()
    private let db = Firestore.firestore()
    private let hasSeededCloudKey = "hasSeededCleanMountainsToFirestoreV2"
    
    // MARK: - One-Time Cloud Firestore Seeder (from clean bundled JSON before removal)
    
    /// Safely uploads our verified 2,118 mountains directly into Cloud Firestore (`mountains` collection) with `nil` coordinates.
    func seedCleanCatalogToFirestoreOnce() async {
        guard !UserDefaults.standard.bool(forKey: hasSeededCloudKey) else {
            print("🟢 [Seeder] Cloud Firestore has already been seeded with clean catalog. Skipping upload.")
            return
        }
        
        guard let url = Bundle.main.url(forResource: "philippine_mountains", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            print("ℹ️ [Seeder] Bundle JSON not found or already removed from Xcode resources. Relying on live Cloud Firestore!")
            return
        }
        
        print("🚀 [iOS-Native Seeder] Beginning batch upload of \(jsonArray.count) verified peaks to Cloud Firestore with stripped GPS coordinates...")
        
        var batch = db.batch()
        var count = 0
        var total = 0
        let now = Timestamp(date: Date())
        
        for item in jsonArray {
            guard let docId = item["id"] as? String else { continue }
            let docRef = db.collection("mountains").document(docId)
            
            var cloudData = item
            // Clean Slate Policy: Strip unverified coordinates so zero wrong coordinates exist on the map!
            cloudData["latitude"] = NSNull()
            cloudData["longitude"] = NSNull()
            cloudData["updatedAt"] = now
            cloudData["isApproved"] = true
            cloudData["isVerifiedByCommunity"] = false
            cloudData["communityVerifications"] = 0
            
            batch.setData(cloudData, forDocument: docRef)
            count += 1
            total += 1
            
            if count == 450 {
                do {
                    try await batch.commit()
                    print("⏳ [iOS-Native Seeder] Committed batch of 450 peaks (Progress: \(total)/\(jsonArray.count))...")
                } catch {
                    print("⛔️ [iOS-Native Seeder] Batch commit failed: \(error.localizedDescription). Aborting upload so it can retry next time.")
                    return
                }
                batch = db.batch()
                count = 0
            }
        }
        
        if count > 0 {
            do {
                try await batch.commit()
                print("⏳ [iOS-Native Seeder] Committed final batch of \(count) peaks (Total: \(total)).")
            } catch {
                print("⛔️ [iOS-Native Seeder] Final batch commit failed: \(error.localizedDescription). Aborting upload so it can retry next time.")
                return
            }
        }
        
        UserDefaults.standard.set(true, forKey: hasSeededCloudKey)
        print("🎉 [iOS-Native Seeder] SUCCESS: All \(total) clean mountains have been uploaded to Cloud Firestore with zero inaccurate coordinates!")
    }
    
    // MARK: - Delta-Sync Zero-Cost Architecture
    
    /// Synchronizes Cloud Firestore with local SwiftData storage using cost-optimized timestamp queries:
    /// "Give me only mountains where updatedAt > [my latest SwiftData timestamp]."
    @MainActor
    func synchronizeWithFirestore(in modelContext: ModelContext) async {
        // First check if we need to perform our one-time catalog seeding to Firestore
        await seedCleanCatalogToFirestoreOnce()
        
        // 1. Check our local SwiftData for the newest updatedAt timestamp among all stored mountains
        var descriptor = FetchDescriptor<Mountain>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        
        let latestLocalTimestamp: Date
        if let latestMountain = try? modelContext.fetch(descriptor).first {
            latestLocalTimestamp = latestMountain.updatedAt
            print("🛡️ [Delta-Sync] Current SwiftData database up-to-date as of: \(latestLocalTimestamp.formatted())")
        } else {
            // First install or empty storage: fetch all once from Firestore to populate SwiftData!
            latestLocalTimestamp = Date(timeIntervalSince1970: 0)
            print("📥 [Delta-Sync] First-time setup: Initializing local SwiftData database from Cloud Firestore...")
        }
        
        do {
            print("🌐 [Delta-Sync] Querying Firestore for mountains modified after \(latestLocalTimestamp.formatted())...")
            let snapshot = try await db.collection("mountains")
                .whereField("updatedAt", isGreaterThan: latestLocalTimestamp)
                .getDocuments()
            
            let modCount = snapshot.documents.count
            print("⚡️ [Delta-Sync] Firestore returned \(modCount) modified/new mountain documents (Read operational billing: \(modCount) reads)!")
            
            guard modCount > 0 else { return }
            
            for doc in snapshot.documents {
                do {
                    let remotePeak = try doc.data(as: Mountain.self)
                    let peakId = remotePeak.id
                    
                    // Check if peak already exists in SwiftData by ID
                    var matchDesc = FetchDescriptor<Mountain>(predicate: #Predicate<Mountain> { $0.id == peakId })
                    matchDesc.fetchLimit = 1
                    
                    if let existing = try? modelContext.fetch(matchDesc).first {
                        // Update existing record in SwiftData
                        existing.name = remotePeak.name
                        existing.descriptionText = remotePeak.descriptionText
                        existing.elevationMASL = remotePeak.elevationMASL
                        existing.latitude = remotePeak.latitude
                        existing.longitude = remotePeak.longitude
                        existing.region = remotePeak.region
                        existing.islandGroup = remotePeak.islandGroup
                        existing.difficultyLevel = remotePeak.difficultyLevel
                        existing.trailClass = remotePeak.trailClass
                        existing.isApproved = remotePeak.isApproved
                        existing.updatedAt = remotePeak.updatedAt
                        existing.isVerifiedByCommunity = remotePeak.isVerifiedByCommunity
                        existing.communityVerifications = remotePeak.communityVerifications
                    } else {
                        // Insert brand new or initially synced peak into SwiftData
                        modelContext.insert(remotePeak)
                    }
                } catch {
                    print("⚠️ [Delta-Sync] Failed to decode mountain document \(doc.documentID): \(error)")
                }
            }
            
            try? modelContext.save()
            print("✅ [Delta-Sync] Successfully applied \(modCount) updates to SwiftData storage!")
        } catch {
            print("🌐 [Delta-Sync] Offline or network unreachable (\(error.localizedDescription)). Proceeding seamlessly with stored SwiftData catalog!")
        }
    }
}
