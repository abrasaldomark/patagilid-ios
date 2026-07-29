//
//  PeaksViewModel.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/27/26.
//

import SwiftUI
import Combine
import FirebaseFirestore

enum PeakSortOrder: String, CaseIterable {
    case highestFirst = "Elevation: High to Low"
    case lowestFirst = "Elevation: Low to High"
    case alphabetical = "Name (A-Z)"
}

@MainActor
class PeaksViewModel: ObservableObject {
    @Published var allPeaks: [Mountain] = []
    @Published var searchText: String = ""
    @Published var selectedIslandGroup: IslandGroup? = nil
    @Published var selectedRegion: String? = nil
    @Published var sortOrder: PeakSortOrder = .highestFirst
    @Published var isLoading: Bool = false
    @Published var stagedPeakIds: Set<String> = []
    
    static weak var shared: PeaksViewModel?
    
    private var mountainsListener: ListenerRegistration?
    
    deinit {
        mountainsListener?.remove()
    }
    
    /// Only approved mountains (or legacy seeded peaks) display in the general catalog.
    var publicPeaks: [Mountain] {
        return allPeaks.filter { $0.isPubliclyApproved }
    }
    
    /// Mountains awaiting admin verification in the review queue.
    var pendingReviewPeaks: [Mountain] {
        return allPeaks.filter { !$0.isPubliclyApproved }
    }
    
    /// Returns available peaks for logging: public peaks plus any pending peaks submitted by this user.
    func peaksAvailableForLogging(forUserId userId: String?) -> [Mountain] {
        return allPeaks.filter { $0.isPubliclyApproved || ($0.contributorId == userId && userId != nil) }
    }
    
    var availableRegions: [String] {
        let candidatePeaks = selectedIslandGroup != nil ? publicPeaks.filter { $0.islandGroup == selectedIslandGroup } : publicPeaks
        let regions = candidatePeaks.map { $0.region }.removingDuplicates()
        return regions.sorted { $0.compare($1, options: [.numeric, .caseInsensitive]) == .orderedAscending }
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
                $0.description.localizedCaseInsensitiveContains(searchText)
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
        loadPeaks()
    }
    
    func loadPeaks() {
        isLoading = true
        // Instantly load the 2,688 bundled peaks without burning network or Firestore read quotas!
        self.allPeaks = MountainDataSeeder.shared.officialMountains
        self.isLoading = false
        
        // Listen for dynamic community submissions in Firestore
        mountainsListener?.remove()
        let db = Firestore.firestore()
        mountainsListener = db.collection("mountains").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let documents = snapshot?.documents else {
                if let error = error {
                    print("⚠️ Error listening to community mountains: \(error.localizedDescription)")
                }
                return
            }
            
            var communityPeaks: [Mountain] = []
            for doc in documents {
                do {
                    let peak = try doc.data(as: Mountain.self)
                    if peak.isApproved == false {
                        print("🔔 Found pending community peak in Cloud Firestore: \(peak.name) (\(peak.id))")
                    }
                    communityPeaks.append(peak)
                } catch {
                    print("⚠️ Failed to decode peak document \(doc.documentID): \(error)")
                }
            }
            
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let staged = self.allPeaks.filter { self.stagedPeakIds.contains($0.id) }
                var combined = MountainDataSeeder.shared.officialMountains
                for peak in communityPeaks {
                    if let idx = combined.firstIndex(where: { $0.id == peak.id || ($0.name.caseInsensitiveCompare(peak.name) == .orderedSame && $0.region == peak.region) }) {
                        combined[idx] = peak
                    } else {
                        combined.append(peak)
                    }
                }
                for stagedPeak in staged {
                    if !combined.contains(where: { $0.id == stagedPeak.id }) {
                        combined.append(stagedPeak)
                    }
                }
                self.allPeaks = combined
            }
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
    
    /// Submits a lightweight custom mountain to Firestore with pending approval status.
    func submitCustomMountain(name: String, elevationMASL: Int, region: String, islandGroup: IslandGroup, difficultyLevel: String, trailClass: String, contributorId: String, contributorEmail: String?, description: String = "Community contributed mountain trail and peak.") async throws -> Mountain {
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
            latitude: 14.5995, // Default/approx coordinate fallback
            longitude: 120.9842,
            region: region.isEmpty ? "Local Region" : region,
            islandGroup: islandGroup,
            difficultyLevel: difficultyLevel,
            trailClass: trailClass,
            isApproved: false,
            contributorId: contributorId,
            contributorEmail: contributorEmail
        )
        
        // Commit-on-Climb: Stage in temporary device memory only! Do NOT push to Firestore or Admin Queue until an ascent log is saved.
        stagedPeakIds.insert(cleanID)
        if !allPeaks.contains(where: { $0.id == cleanID }) {
            allPeaks.append(newPeak)
        }
        print("💡 Staged uncommitted community mountain in local memory: \(cleanID)")
        return newPeak
    }
    
    /// Commits a staged custom mountain to Cloud Firestore upon saving an ascent log.
    func commitStagedMountainIfNeeded(_ mountain: Mountain) async {
        guard stagedPeakIds.contains(mountain.id) else { return }
        let db = Firestore.firestore()
        do {
            try await db.collection("mountains").document(mountain.id).setData(from: mountain)
            stagedPeakIds.remove(mountain.id)
            print("🚀 Commit-on-Climb: Successfully pushed staged peak to Cloud Firestore & Admin Moderation Queue upon log save: \(mountain.id)")
        } catch {
            print("⚠️ Failed to commit staged mountain: \(error.localizedDescription)")
        }
    }
    
    /// Evaporates a staged custom mountain from local memory if the user cancels logging an ascent.
    func discardStagedMountainIfNeeded(_ mountain: Mountain) {
        guard stagedPeakIds.contains(mountain.id) else { return }
        stagedPeakIds.remove(mountain.id)
        allPeaks.removeAll { $0.id == mountain.id }
        print("🗑️ Discarded uncommitted staged mountain from local memory upon cancel/exit: \(mountain.id)")
    }
    
    /// Approves a submitted mountain, making it live in the global catalog.
    func approveMountain(_ mountain: Mountain) async throws {
        var updated = mountain
        updated.isApproved = true
        
        let db = Firestore.firestore()
        try db.collection("mountains").document(mountain.id).setData(from: updated)
        
        if let idx = allPeaks.firstIndex(where: { $0.id == mountain.id }) {
            allPeaks[idx].isApproved = true
        }
    }
    
    /// Declines and removes an inappropriately submitted or rejected mountain.
    func declineMountain(_ mountain: Mountain) async throws {
        let db = Firestore.firestore()
        try await db.collection("mountains").document(mountain.id).delete()
        allPeaks.removeAll { $0.id == mountain.id }
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
        
        // Delete the duplicate peak document from the catalog
        try await db.collection("mountains").document(duplicate.id).delete()
        allPeaks.removeAll { $0.id == duplicate.id }
    }
}

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
