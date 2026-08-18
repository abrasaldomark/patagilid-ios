//
//  MountainsViewModel.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/27/26.
//

import SwiftUI
import Combine
import SwiftData
import FirebaseFirestore

enum PeakSortOrder: String, CaseIterable {
    case highestFirst = "Elevation: High to Low"
    case lowestFirst = "Elevation: Low to High"
    case alphabetical = "Name (A-Z)"
}

@MainActor
class MountainsViewModel: ObservableObject {
    @Published var allPeaks: [Mountain] = []
    @Published var searchText: String = ""
    @Published var selectedIslandGroup: IslandGroup? = nil
    @Published var selectedRegion: String? = nil
    @Published var sortOrder: PeakSortOrder = .highestFirst
    @Published var isLoading: Bool = false
    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double = 0.0
    
    /// Mountains with proposed GPS coordinates awaiting admin verification.
    var pendingGPSPeaks: [Mountain] {
        return allPeaks.filter { $0.pendingLatitude != nil && $0.pendingLongitude != nil }
    }
    
    static weak var shared: MountainsViewModel?
    
    private var modelContext: ModelContext?
    
    /// Only approved mountains display in the general public catalog.
    var publicPeaks: [Mountain] {
        return allPeaks.filter { $0.isPubliclyApproved }
    }
    
    /// Mountains awaiting admin verification in the review queue.
    var pendingReviewPeaks: [Mountain] {
        return allPeaks.filter { !$0.isPubliclyApproved }
    }
    
    /// Total combined count of pending mountain submissions and GPS calibrations for administrative moderation.
    var totalPendingReviewsCount: Int {
        return pendingReviewPeaks.count + pendingGPSPeaks.count
    }
    
    /// Whether there are any pending items awaiting administrative moderation.
    var hasPendingReviews: Bool {
        return totalPendingReviewsCount > 0
    }
    
    // MARK: - User Contributions
    
    /// Mountains submitted by the user that are still pending approval.
    func userPendingMountains(forEmail email: String) -> [Mountain] {
        return allPeaks.filter { !$0.isPubliclyApproved && $0.contributorEmail == email }
    }
    
    /// GPS calibrations proposed by the user that are still pending.
    func userPendingGPS(forEmail email: String) -> [Mountain] {
        return allPeaks.filter { $0.pendingContributorEmail == email }
    }
    
    /// Approved mountain submissions by the user.
    func userApprovedMountains(forEmail email: String) -> [Mountain] {
        return allPeaks.filter { $0.isPubliclyApproved && $0.contributorEmail == email }
    }
    
    /// Returns available peaks for logging: public peaks plus any pending peaks submitted by this user.
    func peaksAvailableForLogging(forUserId userId: String?) -> [Mountain] {
        return allPeaks.filter { $0.isPubliclyApproved || ($0.contributorId == userId && userId != nil) }
    }
    
    var availableRegions: [String] {
        if let island = selectedIslandGroup {
            switch island {
            case .luzon:
                return Array(LocationHelper.canonicalRegions[0...7])
            case .visayas:
                return Array(LocationHelper.canonicalRegions[8...11])
            case .mindanao:
                return Array(LocationHelper.canonicalRegions[12...17])
            }
        }
        return LocationHelper.canonicalRegions
    }
    
    var filteredAndSortedPeaks: [Mountain] {
        var result = publicPeaks
        
        // Island Group filter
        if let group = selectedIslandGroup {
            result = result.filter { $0.islandGroup == group }
        }
        
        // Region filter
        if let region = selectedRegion {
            result = result.filter { $0.region == region }
        }
        
        // Search text
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.region.localizedCaseInsensitiveContains(searchText) ||
                $0.descriptionText.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort order
        switch sortOrder {
        case .highestFirst:
            result.sort { $0.elevationMASL > $1.elevationMASL }
        case .lowestFirst:
            result.sort { $0.elevationMASL < $1.elevationMASL }
        case .alphabetical:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        
        return result
    }
    
    init() {
        Self.shared = self
    }
    
    // MARK: - SwiftData & Delta-Sync Integration
    
    /// Binds the active SwiftData ModelContext and performs instant local read + cost-optimized Firestore Delta-Sync.
    func synchronize(in context: ModelContext) async {
        self.modelContext = context
        self.isDownloading = true
        self.downloadProgress = 0.05 // Immediate visible indicator while checking network/Firestore
        
        // 1. Instantly load from local high-speed SwiftData storage
        self.isLoading = true
        refreshFromSwiftData(in: context)
        if !allPeaks.isEmpty {
            self.isLoading = false
        }
        
        // 2. Perform cost-optimized Delta-Sync in Cloud Firestore ("Give me only mountains where updatedAt > local timestamp")
        await MountainSyncService.shared.synchronizeWithFirestore(in: context) { [weak self] processed, total in
            guard let self = self else { return }
            self.downloadProgress = total > 0 ? Double(processed) / Double(total) : 1.0
            self.refreshFromSwiftData(in: context)
        }
        
        // 3. Update active memory list with newly synchronized records
        refreshFromSwiftData(in: context)
        self.downloadProgress = 1.0
        try? await Task.sleep(nanoseconds: 250_000_000) // Brief 0.25s pause so full bar finishes animating smoothly before hiding
        self.isLoading = false
        self.isDownloading = false
        self.downloadProgress = 0.0
    }
    
    func refreshFromSwiftData(in context: ModelContext) {
        var descriptor = FetchDescriptor<Mountain>(sortBy: [SortDescriptor(\.name)])
        if let stored = try? context.fetch(descriptor) {
            var combined = stored

            self.allPeaks = combined
        }
    }
    
    func selectIslandGroup(_ group: IslandGroup?) {
        selectedIslandGroup = group
        selectedRegion = nil
    }
    
    func selectRegion(_ region: String?) {
        selectedRegion = region
        if let region = region, let match = publicPeaks.first(where: { $0.region == region }) {
            selectedIslandGroup = match.islandGroup
        }
    }
    
    func resetFilters() {
        selectedIslandGroup = nil
        selectedRegion = nil
        searchText = ""
        sortOrder = .highestFirst
    }
    
    // MARK: - Community Submission & Moderation Actions
    
    /// Submits a lightweight custom mountain with pending approval status and unmapped (`nil`) GPS coordinates.
    func submitCustomMountain(name: String, elevationMASL: Int, region: String, islandGroup: IslandGroup, difficultyLevel: String, trailClass: String, contributorId: String, contributorEmail: String?, contributorName: String? = nil, description: String = "Community contributed mountain trail and peak.") async throws -> Mountain {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let slug = cleanName.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: ".", with: "")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-")).inverted)
            .joined()
        let cleanID = "custom_\(slug)_\(Int(Date().timeIntervalSince1970))"
        
        let newPeak = Mountain(
            id: cleanID,
            name: cleanName,
            description: description,
            elevationMASL: elevationMASL,
            latitude: nil, // Clean slate: no estimated/inaccurate coordinates!
            longitude: nil,
            region: region.isEmpty ? "Local Region" : region,
            islandGroup: islandGroup,
            difficultyLevel: difficultyLevel,
            trailClass: trailClass,
            isApproved: false,
            contributorId: contributorId,
            contributorEmail: contributorEmail,
            contributorName: contributorName,
            updatedAt: Date()
        )
        
        let db = Firestore.firestore()
        try await db.collection("mountains").document(cleanID).setData(from: newPeak)
        if let context = modelContext {
            context.insert(newPeak)
            try? context.save()
        }
        
        if !allPeaks.contains(where: { $0.id == cleanID }) {
            allPeaks.append(newPeak)
        }
        print("🚀 Submitted new custom mountain directly to Cloud Firestore: \(cleanID)")
        return newPeak
    }
    
    /// Approves a submitted mountain, making it live on the public mountain list.
    func approveMountain(_ mountain: Mountain) async throws {
        mountain.isApproved = true
        mountain.updatedAt = Date()
        
        let db = Firestore.firestore()
        try db.collection("mountains").document(mountain.id).setData(from: mountain)
        try? modelContext?.save()
    }
    
    /// Declines and removes an inappropriately submitted or rejected mountain.
    func declineMountain(_ mountain: Mountain) async throws {
        let db = Firestore.firestore()
        try await db.collection("mountains").document(mountain.id).delete()
        if let context = modelContext {
            context.delete(mountain)
            try? context.save()
        }
        allPeaks.removeAll { $0.id == mountain.id }
    }
    
    /// Approves a proposed GPS coordinate calibration on a mountain.
    func approveGPS(for mountain: Mountain) async throws {
        guard let lat = mountain.pendingLatitude, let lon = mountain.pendingLongitude else { return }
        let newRegion = mountain.pendingRegion ?? mountain.region
        
        mountain.latitude = lat
        mountain.longitude = lon
        mountain.region = newRegion
        mountain.isVerifiedByCommunity = true
        mountain.communityVerifications += (1 + mountain.pendingVerifications)
        mountain.pendingLatitude = nil
        mountain.pendingLongitude = nil
        mountain.pendingRegion = nil
        mountain.pendingContributorEmail = nil
        mountain.pendingContributorName = nil
        mountain.pendingVerifications = 0
        mountain.pendingVerifierEmails = []
        mountain.updatedAt = Date()
        
        let db = Firestore.firestore()
        try db.collection("mountains").document(mountain.id).setData(from: mountain)
        try? modelContext?.save()
        objectWillChange.send()
    }
    
    /// Declines a proposed GPS coordinate calibration without modifying existing coordinates.
    func declineGPS(for mountain: Mountain) async throws {
        mountain.pendingLatitude = nil
        mountain.pendingLongitude = nil
        mountain.pendingRegion = nil
        mountain.pendingContributorEmail = nil
        mountain.pendingContributorName = nil
        mountain.pendingVerifications = 0
        mountain.pendingVerifierEmails = []
        mountain.updatedAt = Date()
        
        let db = Firestore.firestore()
        try db.collection("mountains").document(mountain.id).setData(from: mountain)
        try? modelContext?.save()
        objectWillChange.send()
    }
    
    /// Confirms and verifies a pending GPS coordinate calibration by another mountaineer.
    func verifyPendingGPS(for mountain: Mountain, userEmail: String) async throws {
        guard !mountain.pendingVerifierEmails.contains(userEmail), mountain.pendingContributorEmail != userEmail else { return }
        mountain.pendingVerifierEmails.append(userEmail)
        mountain.pendingVerifications = mountain.pendingVerifierEmails.count
        mountain.updatedAt = Date()
        
        let db = Firestore.firestore()
        try db.collection("mountains").document(mountain.id).setData(from: mountain)
        try? modelContext?.save()
        objectWillChange.send()
    }
    
    /// Merges a duplicate submission into a target canonical mountain, automatically re-linking user hike logs.
    func mergeMountain(duplicate: Mountain, into target: Mountain) async throws {
        let db = Firestore.firestore()
        
        // Use a collection group query to locate all HikeLog records referencing the duplicate mountain
        let snapshot = try await db.collectionGroup("hikeLogs")
        .whereField("mountainId", isEqualTo: duplicate.id)
        .getDocuments()
        
        // Update each log to point to the canonical approved mountain ID
        for doc in snapshot.documents {
            try await doc.reference.updateData(["mountainId": target.id])
        }
        
        // Delete the duplicate peak document from the mountain list
        try await db.collection("mountains").document(duplicate.id).delete()
        if let context = modelContext {
            context.delete(duplicate)
            try? context.save()
        }
        allPeaks.removeAll { $0.id == duplicate.id }
    }
}

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
