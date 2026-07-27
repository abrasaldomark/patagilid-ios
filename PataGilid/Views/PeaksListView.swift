//
//  PeaksListView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/27/26.
//

import SwiftUI

/// An interactive, responsive explorer presenting all 2,688 Philippine mountain peaks with search, filtering, and sorting.
struct PeaksListView: View {
    @StateObject private var viewModel = PeaksViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Island Group Filter Bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        FilterPill(title: "All (\(viewModel.allPeaks.count))", isSelected: viewModel.selectedIslandGroup == nil && viewModel.selectedRegion == nil) {
                            viewModel.resetFilters()
                        }
                        
                        ForEach(IslandGroup.allCases) { group in
                            FilterPill(title: group.rawValue, isSelected: viewModel.selectedIslandGroup == group) {
                                viewModel.selectIslandGroup(group)
                            }
                        }
                        
                        // Active Region Badge indicator
                        if let activeRegion = viewModel.selectedRegion {
                            HStack(spacing: 4) {
                                Text(activeRegion)
                                    .lineLimit(1)
                                Image(systemName: "xmark.circle.fill")
                            }
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .clipShape(Capsule())
                            .onTapGesture {
                                viewModel.selectedRegion = nil
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                .background(Color.secondary.opacity(0.06))
                
                // Peak Count Banner
                HStack {
                    Text("Showing \(viewModel.filteredAndSortedPeaks.count) of \(viewModel.allPeaks.count) Peaks")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                
                // Mountain List
                List {
                    ForEach(viewModel.filteredAndSortedPeaks) { mountain in
                        NavigationLink(destination: PeakDetailView(mountain: mountain)) {
                            PeakRowView(mountain: mountain)
                        }
                        .listRowSeparator(.visible)
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    }
                }
                .listStyle(.plain)
                .searchable(text: $viewModel.searchText, prompt: "Search by Name, Region (e.g. Region 6), or Details")
            }
            .navigationTitle("Philippine Peaks")
            .toolbar {
                // Sorting & Region Filters Menu
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Section(header: Text("Sort Order")) {
                            ForEach(PeakSortOrder.allCases, id: \.self) { order in
                                Button(action: { viewModel.sortOrder = order }) {
                                    HStack {
                                        Text(order.rawValue)
                                        if viewModel.sortOrder == order {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                        
                        Section(header: Text("Filter by Region")) {
                            Button(action: { viewModel.selectRegion(nil) }) {
                                Text("All Regions")
                            }
                            
                            ForEach(viewModel.availableRegions, id: \.self) { region in
                                Button(action: {
                                    viewModel.selectRegion(region)
                                }) {
                                    HStack {
                                        Text(region)
                                        if viewModel.selectedRegion == region {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .font(.title3)
                            .foregroundColor(.teal)
                    }
                }
            }
        }
    }
}

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .bold : .semibold)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.emeraldGreen : Color.secondary.opacity(0.15))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
                .shadow(color: isSelected ? Color.emeraldGreen.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
        }
    }
}

struct PeakRowView: View {
    let mountain: Mountain
    
    var body: some View {
        HStack(spacing: 14) {
            MountainHeaderImageView(mountain: mountain, isThumbnail: true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(mountain.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(mountain.region)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(mountain.elevationMASL)")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
                Text("MASL")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
        .contentShape(Rectangle())
    }
    
    private func islandColor(for group: IslandGroup) -> Color {
        switch group {
        case .luzon: return .emeraldGreen
        case .visayas: return .teal
        case .mindanao: return .blue
        }
    }
}

#Preview {
    PeaksListView()
}
