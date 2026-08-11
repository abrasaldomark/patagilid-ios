//
//  SummitLogsViewModel.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/28/26.
//

import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

enum LogSortOrder: String, CaseIterable {
    case mostRecent = "Most Recent"
    case oldestFirst = "Oldest First"
    case highestElevation = "Highest Peak"
    case alphabetical = "Mountain Name (A-Z)"
}

enum LogOutcomeFilter: String, CaseIterable {
    case all = "All Outcomes"
    case summited = "Summited Only"
    case backedOut = "Backed Out"
}

/// ViewModel providing a real-time feed of the signed-in hiker's personal summit logs
/// from `users/{userId}/hikeLogs`, ordered by most recent attempt first.
@MainActor
class SummitLogsViewModel: ObservableObject {
    @Published var logs: [HikeLog] = []
    @Published var isLoading: Bool = true
    @Published var errorMessage: String? = nil
    
    // MARK: - Filtering & Sorting State
    @Published var searchText: String = ""
    @Published var selectedIslandGroup: IslandGroup? = nil
    @Published var selectedRegion: String? = nil
    @Published var selectedOutcome: LogOutcomeFilter = .all
    @Published var sortOrder: LogSortOrder = .mostRecent
    
    /// O(1) mountain lookup map built from the bundled JSON catalog.
    private(set) var mountainMap: [String: Mountain] = [:]
    private var listener: ListenerRegistration?
    
    init() {
        buildMountainMap()
        subscribe()
    }
    
    deinit {
        listener?.remove()
    }
    
    // MARK: - Mountain Lookup
    
    func mountain(for id: String) -> Mountain? {
        if let match = mountainMap[id] {
            return match
        }
        if let match = MountainsViewModel.shared?.allPeaks.first(where: { $0.id == id }) {
            mountainMap[id] = match
            return match
        }
        return nil
    }
    
    func refreshMountainMap() {
        let all = MountainsViewModel.shared?.allPeaks ?? []
        var newMap: [String: Mountain] = [:]
        for peak in all {
            newMap[peak.id] = peak
        }
        self.mountainMap = newMap
    }
    
    private func buildMountainMap() {
        refreshMountainMap()
    }
    
    // MARK: - Filtering & Sorting Logic
    
    func resetFilters() {
        selectedIslandGroup = nil
        selectedRegion = nil
        selectedOutcome = .all
        searchText = ""
        sortOrder = .mostRecent
    }
    
    func selectIslandGroup(_ group: IslandGroup) {
        if selectedIslandGroup == group {
            selectedIslandGroup = nil
        } else {
            selectedIslandGroup = group
            selectedRegion = nil
        }
    }
    
    func selectRegion(_ region: String?) {
        selectedRegion = region
    }
    
    func availableRegions(using allPeaks: [Mountain]) -> [String] {
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
    
    func filteredAndSortedLogs(using allPeaks: [Mountain]) -> [HikeLog] {
        var result = logs
        
        // Island Group filter
        if let group = selectedIslandGroup {
            result = result.filter { log in
                let m = allPeaks.first(where: { $0.id == log.mountainId }) ?? mountainMap[log.mountainId]
                return m?.islandGroup == group
            }
        }
        
        // Region filter
        if let region = selectedRegion {
            result = result.filter { log in
                let m = allPeaks.first(where: { $0.id == log.mountainId }) ?? mountainMap[log.mountainId]
                return m?.region == region
            }
        }
        
        // Outcome filter
        switch selectedOutcome {
        case .all:
            break
        case .summited:
            result = result.filter { $0.didSummit }
        case .backedOut:
            result = result.filter { !$0.didSummit }
        }
        
        // Search text filter
        if !searchText.isEmpty {
            result = result.filter { log in
                let m = allPeaks.first(where: { $0.id == log.mountainId }) ?? mountainMap[log.mountainId]
                let nameMatch = m?.name.localizedCaseInsensitiveContains(searchText) == true
                let regionMatch = m?.region.localizedCaseInsensitiveContains(searchText) == true
                let trailMatch = log.trailName.localizedCaseInsensitiveContains(searchText)
                let exitMatch = log.exitTrailName.localizedCaseInsensitiveContains(searchText)
                return nameMatch || regionMatch || trailMatch || exitMatch
            }
        }
        
        // Sorting
        switch sortOrder {
        case .mostRecent:
            result.sort { $0.dateTimeStart > $1.dateTimeStart }
        case .oldestFirst:
            result.sort { $0.dateTimeStart < $1.dateTimeStart }
        case .highestElevation:
            result.sort { log1, log2 in
                let m1Elev = (allPeaks.first(where: { $0.id == log1.mountainId }) ?? mountainMap[log1.mountainId])?.elevationMASL ?? 0
                let m2Elev = (allPeaks.first(where: { $0.id == log2.mountainId }) ?? mountainMap[log2.mountainId])?.elevationMASL ?? 0
                return m1Elev > m2Elev
            }
        case .alphabetical:
            result.sort { log1, log2 in
                let name1 = (allPeaks.first(where: { $0.id == log1.mountainId }) ?? mountainMap[log1.mountainId])?.name ?? ""
                let name2 = (allPeaks.first(where: { $0.id == log2.mountainId }) ?? mountainMap[log2.mountainId])?.name ?? ""
                return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
            }
        }
        
        return result
    }
    
    // MARK: - Firestore Listener
    
    func subscribe() {
        guard let user = Auth.auth().currentUser else {
            isLoading = false
            errorMessage = "Sign in to view your summit logs."
            return
        }
        
        isLoading = true
        errorMessage = nil
        listener?.remove()
        
        listener = Firestore.firestore()
            .collection("users")
            .document(user.uid)
            .collection("hikeLogs")
            .order(by: "dateTimeStart", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                isLoading = false
                if let error {
                    errorMessage = error.localizedDescription
                    // Offline fallback: restore directly from hiker's private Google Drive backup!
                    Task {
                        if let restored = try? await GoogleDriveService.shared.loadSummitLogs(), !restored.isEmpty {
                            await MainActor.run {
                                self.logs = restored
                                self.errorMessage = nil
                            }
                        }
                    }
                    return
                }
                let fetchedLogs: [HikeLog] = snapshot?.documents.compactMap {
                    try? $0.data(as: HikeLog.self)
                } ?? []
                logs = fetchedLogs
                
                // Simultaneously sync & preserve hiker's personal climbing legacy to their Google Drive!
                if !fetchedLogs.isEmpty {
                    Task {
                        try? await GoogleDriveService.shared.saveSummitLogs(fetchedLogs)
                    }
                }
            }
    }
    
    // MARK: - Deletion
    
    func delete(_ log: HikeLog) {
        guard let user = Auth.auth().currentUser, let logId = log.id else { return }
        if !log.photoUrls.isEmpty {
            Task {
                print("🗑️ Removing \(log.photoUrls.count) photos from Google Drive for deleted summit log...")
                await GoogleDriveService.shared.deletePhotos(atUrls: log.photoUrls)
            }
        }
        Firestore.firestore()
            .collection("users").document(user.uid)
            .collection("hikeLogs").document(logId)
            .delete()
    }
}
