//
//  MountainListDetailView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 8/15/26.
//

import SwiftUI
import SwiftData

/// Shows the mountains inside a specific user list with remove-from-list capability.
/// Uses the same shared filter components as the Mountains tab and My Climbs tab.
struct MountainListDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var listsViewModel: MountainListsViewModel
    @EnvironmentObject private var mountainsViewModel: MountainsViewModel

    /// The list being displayed. Observed directly from SwiftData so UI stays reactive.
    @Bindable var list: MountainList

    @Query(sort: \Mountain.name)
    private var allMountains: [Mountain]

    @State private var removeTarget: Mountain? = nil
    @State private var isSearchVisible: Bool = false
    @State private var searchText: String = ""
    @State private var selectedIslandGroup: IslandGroup? = nil
    @State private var selectedRegion: String? = nil
    @State private var sortOrder: PeakSortOrder = .highestFirst

    /// Mountains in this list, resolved from local SwiftData cache in list order.
    private var listMountains: [Mountain] {
        list.mountainIds.compactMap { id in
            allMountains.first { $0.id == id }
        }
    }

    /// Filtered and sorted mountains for display.
    private var filteredMountains: [Mountain] {
        var result = listMountains

        // Island group filter
        if let group = selectedIslandGroup {
            result = result.filter { $0.islandGroup == group }
        }

        // Region filter
        if let region = selectedRegion {
            result = result.filter { $0.region == region }
        }

        // Search filter
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !query.isEmpty {
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                $0.region.lowercased().contains(query)
            }
        }

        // Sort
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

    /// Available regions derived from the mountains in this specific list.
    private var availableRegions: [String] {
        Array(Set(listMountains.map(\.region))).sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Island Group Filter Bar
            if !listMountains.isEmpty {
                IslandGroupFilterBar(
                    allCount: listMountains.count,
                    selectedIslandGroup: selectedIslandGroup,
                    selectedRegion: selectedRegion,
                    isAllSelected: selectedIslandGroup == nil && selectedRegion == nil,
                    onResetFilters: { resetFilters() },
                    onSelectIslandGroup: { selectIslandGroup($0) },
                    onClearRegion: { selectedRegion = nil }
                )
            }

            // Count Banner
            CountBanner(
                filteredCount: filteredMountains.count,
                totalCount: listMountains.count,
                noun: "Mountains"
            )

            if listMountains.isEmpty {
                emptyState
            } else if filteredMountains.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 52))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text(searchText.isEmpty ? "No mountains match active filters" : "No mountains matched '\(searchText)'")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Button("Reset Filters") {
                        resetFilters()
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.gliderBlue)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                mountainList
            }
        }
        .conditionalSearchable(text: $searchText, isPresented: $isSearchVisible, prompt: "Search by Name or Region")
        .navigationTitle(list.displayTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !listMountains.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    SearchFilterToolbar(isSearchVisible: $isSearchVisible) {
                        SortOrderMenuSection(
                            currentOrder: sortOrder,
                            onSelect: { sortOrder = $0 }
                        )

                        RegionFilterMenuSection(
                            availableRegions: availableRegions,
                            selectedRegion: selectedRegion,
                            onSelectRegion: { selectedRegion = $0 }
                        )
                    }
                }
            }
        }
        .alert("Remove from List?", isPresented: Binding(
            get: { removeTarget != nil },
            set: { if !$0 { removeTarget = nil } }
        )) {
            Button("Remove", role: .destructive) {
                if let target = removeTarget {
                    Task {
                        await listsViewModel.removeMountain(id: target.id, from: list, in: modelContext)
                    }
                }
                removeTarget = nil
            }
            Button("Cancel", role: .cancel) { removeTarget = nil }
        } message: {
            Text("\(removeTarget?.name ?? "") will be removed from this list. Your climb logs are not affected.")
        }
    }

    // MARK: - Helpers

    private func resetFilters() {
        selectedIslandGroup = nil
        selectedRegion = nil
    }

    private func selectIslandGroup(_ group: IslandGroup) {
        if selectedIslandGroup == group {
            selectedIslandGroup = nil
        } else {
            selectedIslandGroup = group
            selectedRegion = nil
        }
    }

    // MARK: - Mountain List

    private var mountainList: some View {
        List {
            ForEach(filteredMountains) { mountain in
                NavigationLink(destination: MountainDetailView(mountain: mountain)) {
                    MountainRowView(mountain: mountain)
                }
                .listRowSeparator(.visible)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        removeTarget = mountain
                    } label: {
                        Label("Remove", systemImage: "minus.circle")
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("🗺️")
                .font(.system(size: 56))
            Text("This List is Empty")
                .font(.title2)
                .fontWeight(.bold)
            Text("Open a mountain's detail page and\ntap \"Save to List\" to add it here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
