//
//  PeaksViewModel.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/27/26.
//

import SwiftUI
import Combine

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
    
    var availableRegions: [String] {
        let candidatePeaks = selectedIslandGroup != nil ? allPeaks.filter { $0.islandGroup == selectedIslandGroup } : allPeaks
        let regions = candidatePeaks.map { $0.region }.removingDuplicates()
        return regions.sorted { $0.compare($1, options: [.numeric, .caseInsensitive]) == .orderedAscending }
    }
    
    var filteredAndSortedPeaks: [Mountain] {
        var result = allPeaks
        
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
        loadPeaks()
    }
    
    func loadPeaks() {
        isLoading = true
        // Instantly load the 2,688 bundled peaks without burning network or Firestore read quotas!
        self.allPeaks = MountainDataSeeder.shared.officialMountains
        self.isLoading = false
    }
    
    func selectIslandGroup(_ group: IslandGroup?) {
        selectedIslandGroup = group
        selectedRegion = nil // Clear any regional sub-filter while keeping the Island Group firmly selected
    }
    
    func selectRegion(_ region: String?) {
        selectedRegion = region
        if let region = region, let match = allPeaks.first(where: { $0.region == region }) {
            selectedIslandGroup = match.islandGroup
        }
    }
    
    func resetFilters() {
        selectedIslandGroup = nil
        selectedRegion = nil
        searchText = ""
        sortOrder = .highestFirst
    }
}

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
