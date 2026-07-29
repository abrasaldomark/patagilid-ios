//
//  PeaksListView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/27/26.
//

import SwiftUI

/// An interactive, responsive explorer presenting all 2,688 Philippine mountain peaks with search, filtering, and sorting.
struct PeaksListView: View {
    @EnvironmentObject var viewModel: PeaksViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var showAddCustomPeak: Bool = false
    @State private var showAdminQueue: Bool = false
    @State private var selectedNewPeak: Mountain? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - In-App Admin Review Banner
                if authViewModel.isAdmin {
                    Button {
                        showAdminQueue = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: viewModel.pendingReviewPeaks.isEmpty ? "shield.checkmark.fill" : "shield.checkerboard")
                                .font(.title2)
                                .foregroundColor(.white)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.pendingReviewPeaks.isEmpty ? "Admin Superpowers Active" : "🔔 Admin Review Queue")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Text(viewModel.pendingReviewPeaks.isEmpty ? "0 pending community submissions • All clear!" : "\(viewModel.pendingReviewPeaks.count) community peak(s) awaiting verification • Tap to Action")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.95))
                            }
                            Spacer()
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            viewModel.pendingReviewPeaks.isEmpty ?
                            LinearGradient(gradient: Gradient(colors: [Color.emeraldGreen, Color.teal]), startPoint: .leading, endPoint: .trailing) :
                            LinearGradient(gradient: Gradient(colors: [Color.orange, Color.red]), startPoint: .leading, endPoint: .trailing)
                        )
                        .shadow(color: (viewModel.pendingReviewPeaks.isEmpty ? Color.teal : Color.orange).opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
                
                // Island Group Filter Bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        FilterPill(title: "All (\(viewModel.publicPeaks.count))", isSelected: viewModel.selectedIslandGroup == nil && viewModel.selectedRegion == nil) {
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
                    Text("Showing \(viewModel.filteredAndSortedPeaks.count) of \(viewModel.publicPeaks.count) Peaks")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                
                // Mountain List & Empty Search State
                if viewModel.filteredAndSortedPeaks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "mountain.2.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text(viewModel.searchText.isEmpty ? "No peaks found" : "No peaks matched '\(viewModel.searchText)'")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Can't find the local mountain or trail you climbed? Contribute it directly to PataGilid!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button {
                            showAddCustomPeak = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                Text("Contribute Missing Peak")
                            }
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.emeraldGreen)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(color: Color.emeraldGreen.opacity(0.3), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
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
                    .refreshable {
                        let updated = await MountainDataSeeder.shared.fetchLatestCatalogFromFirebase()
                        if updated {
                            viewModel.refreshCombinedPeaks()
                        }
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search by Name, Region (e.g. Region 6), or Details")
            .navigationTitle("Philippine Peaks")
            .navigationDestination(item: $selectedNewPeak) { peak in
                PeakDetailView(mountain: peak)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showAddCustomPeak = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Peak")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.emeraldGreen)
                    }
                }
                
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
            .sheet(isPresented: $showAddCustomPeak) {
                AddCustomMountainView { newPeak in
                    selectedNewPeak = newPeak
                }
                .environmentObject(authViewModel)
                .environmentObject(viewModel)
            }
            .sheet(isPresented: $showAdminQueue) {
                AdminModerationQueueView()
                    .environmentObject(viewModel)
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
        .environmentObject(PeaksViewModel())
        .environmentObject(AuthViewModel())
}
