//
//  MountainsListView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/27/26.
//

import SwiftUI
import SwiftData

/// An interactive, responsive explorer presenting all 2,688 Philippine mountain peaks with search, filtering, and sorting.
struct MountainsListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var viewModel: MountainsViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var showAddCustomPeak: Bool = false
    @State private var showAdminQueue: Bool = false
    @State private var selectedNewPeak: Mountain? = nil
    @State private var isSearchVisible: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - In-App Admin Review Banner
                if authViewModel.isAdmin {
                    Button {
                        showAdminQueue = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: !viewModel.hasPendingReviews ? "shield.checkmark.fill" : "shield.checkerboard")
                                .font(.title2)
                                .foregroundColor(.white)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(!viewModel.hasPendingReviews ? "Admin Superpowers Active" : "🔔 Admin Review Queue")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Text(!viewModel.hasPendingReviews ? "0 pending community submissions • All clear!" : "\(viewModel.totalPendingReviewsCount) community submission(s) awaiting verification • Tap to Action")
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
                            !viewModel.hasPendingReviews ?
                            LinearGradient(gradient: Gradient(colors: [Color.gliderBlue, Color.summitSteel]), startPoint: .leading, endPoint: .trailing) :
                            LinearGradient(gradient: Gradient(colors: [Color.gliderBlue, Color.blue]), startPoint: .leading, endPoint: .trailing)
                        )
                        .shadow(color: Color.gliderBlue.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
                
                // Island Group Filter Bar
                IslandGroupFilterBar(
                    allCount: viewModel.publicPeaks.count,
                    selectedIslandGroup: viewModel.selectedIslandGroup,
                    selectedRegion: viewModel.selectedRegion,
                    isAllSelected: viewModel.selectedIslandGroup == nil && viewModel.selectedRegion == nil,
                    onResetFilters: { viewModel.resetFilters() },
                    onSelectIslandGroup: { viewModel.selectIslandGroup($0) },
                    onClearRegion: { viewModel.selectedRegion = nil }
                )
                
                // Peak Count Banner
                CountBanner(
                    filteredCount: viewModel.filteredAndSortedPeaks.count,
                    totalCount: viewModel.publicPeaks.count,
                    noun: "Mountains"
                )
                
                // Ultra-thin progress bar displayed when downloading/synchronizing mountains
                if viewModel.isDownloading || viewModel.isLoading {
                    ProgressView(value: viewModel.downloadProgress > 0 ? viewModel.downloadProgress : 0.05, total: 1.0)
                        .progressViewStyle(.linear)
                        .tint(.gliderBlue)
                        .background(Color.gliderBlue.opacity(0.15))
                        .frame(maxWidth: .infinity)
                        .frame(height: 3)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.downloadProgress)
                } else {
                    Color.clear.frame(height: 3)
                }
                
                // Mountain List, Skeleton Loader & Empty Search State
                Group {
                    if (viewModel.isLoading || viewModel.isDownloading) && viewModel.filteredAndSortedPeaks.isEmpty {
                        List {
                            ForEach(0..<8, id: \.self) { _ in
                                SkeletonMountainCardView()
                                    .listRowSeparator(.visible)
                                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                                    .allowsHitTesting(false)
                            }
                        }
                        .listStyle(.plain)
                    } else if viewModel.filteredAndSortedPeaks.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "mountain.2.fill")
                                .font(.system(size: 56))
                                .foregroundColor(.secondary.opacity(0.4))
                            Text(viewModel.searchText.isEmpty ? "No mountains found" : "No mountains matched '\(viewModel.searchText)'")
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
                                    Text("Contribute Missing Mountain")
                                }
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.gliderBlue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .shadow(color: Color.gliderBlue.opacity(0.3), radius: 6, x: 0, y: 3)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemGroupedBackground))
                    } else {
                        List {
                            ForEach(viewModel.filteredAndSortedPeaks) { mountain in
                                NavigationLink(destination: MountainDetailView(mountain: mountain)) {
                                    MountainRowView(mountain: mountain)
                                }
                                .listRowSeparator(.visible)
                                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                            }
                        }
                        .listStyle(.plain)
                    }
                }
                .conditionalSearchable(text: $viewModel.searchText, isPresented: $isSearchVisible, prompt: "Search Mountain, Region, or Trail")
            }
            .navigationTitle("Philippine Mountains")
            .navigationDestination(item: $selectedNewPeak) { peak in
                MountainDetailView(mountain: peak)
            }
            .toolbar {
                // Sorting & Region Filters Menu
                ToolbarItem(placement: .navigationBarTrailing) {
                    SearchFilterToolbar(
                        isSearchVisible: $isSearchVisible,
                        onAdd: { showAddCustomPeak = true }
                    ) {
                        SortOrderMenuSection(
                            currentOrder: viewModel.sortOrder,
                            onSelect: { viewModel.sortOrder = $0 }
                        )
                        
                        RegionFilterMenuSection(
                            availableRegions: viewModel.availableRegions,
                            selectedRegion: viewModel.selectedRegion,
                            onSelectRegion: { viewModel.selectRegion($0) }
                        )
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
                    .environmentObject(authViewModel)
            }
        }
    }
}


struct MountainRowView: View {
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
        case .luzon: return .gliderBlue
        case .visayas: return .summitSteel
        case .mindanao: return .blue
        }
    }
}
#Preview {
    MountainsListView()
        .environmentObject(MountainsViewModel())
        .environmentObject(AuthViewModel())
}
