//
//  MountainSyncService.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/27/26.
//

import Foundation
import SwiftData
import FirebaseFirestore

/// A dedicated service class responsible for syncing Cloud Firestore (`mountains` collection)
/// with the user's high-speed local SwiftData persistence database using cost-optimized Delta-Sync architecture.
class MountainSyncService {
    static let shared = MountainSyncService()
    private let db = Firestore.firestore()
    
    // MARK: - Delta-Sync Zero-Cost Architecture
    
    /// Synchronizes Cloud Firestore with local SwiftData storage using cost-optimized timestamp queries:
    /// "Give me only mountains where updatedAt > [my latest SwiftData timestamp]."
    @MainActor
    func synchronizeWithFirestore(in modelContext: ModelContext, onProgress: ((Int, Int) -> Void)? = nil) async {
        
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
            
            var appliedCount = 0
            var processedIDs = Set<String>()
            
            for (index, doc) in snapshot.documents.enumerated() {
                do {
                    let remotePeak = try doc.data(as: Mountain.self)
                    let peakId = remotePeak.id
                    
                    guard !processedIDs.contains(peakId) else {
                        print("⚠️ [Delta-Sync] Skipping duplicate mountain ID in batch: \(peakId)")
                        continue
                    }
                    processedIDs.insert(peakId)
                    
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
                        existing.contributorName = remotePeak.contributorName
                        existing.updatedAt = remotePeak.updatedAt
                        existing.isVerifiedByCommunity = remotePeak.isVerifiedByCommunity
                        existing.communityVerifications = remotePeak.communityVerifications
                        existing.pendingLatitude = remotePeak.pendingLatitude
                        existing.pendingLongitude = remotePeak.pendingLongitude
                        existing.pendingRegion = remotePeak.pendingRegion
                        existing.pendingContributorEmail = remotePeak.pendingContributorEmail
                        existing.pendingContributorName = remotePeak.pendingContributorName
                        existing.pendingVerifications = remotePeak.pendingVerifications
                        existing.pendingVerifierEmails = remotePeak.pendingVerifierEmails
                    } else {
                        // Insert brand new or initially synced peak into SwiftData
                        modelContext.insert(remotePeak)
                    }
                    appliedCount += 1
                    
                    // Commit to SwiftData in small responsive batches (every 30 peaks or on final peak)
                    if appliedCount % 30 == 0 || index == modCount - 1 {
                        try? modelContext.save()
                        onProgress?(appliedCount, modCount)
                        // Yield to SwiftUI render loop so numbers increment smoothly and progress bar fills up!
                        try? await Task.sleep(nanoseconds: 12_000_000) // 12ms
                    }
                } catch {
                    print("⚠️ [Delta-Sync] Failed to decode mountain document \(doc.documentID): \(error)")
                }
            }
            
            do {
                try modelContext.save()
                print("✅ [Delta-Sync] Successfully applied and saved \(appliedCount) updates to SwiftData storage!")
            } catch {
                print("❌ [Delta-Sync] Failed to commit updates to SwiftData: \(error)")
                print("⚠️ [Delta-Sync] Detailed error description: \(error.localizedDescription)")
            }
        } catch {
            print("🌐 [Delta-Sync] Offline or network unreachable (\(error.localizedDescription)). Proceeding seamlessly with stored SwiftData catalog!")
        }
    }
}
