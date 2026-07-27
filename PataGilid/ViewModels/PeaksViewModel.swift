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
        let regions = allPeaks.map { $0.region }.removingDuplicates()
        return regions.sorted()
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
        if selectedIslandGroup == group {
            selectedIslandGroup = nil // Toggle off
        } else {
            selectedIslandGroup = group
            selectedRegion = nil // Reset regional filter on group change
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
