//
//  MountainsListView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/27/26.
//

import SwiftUI

/// An interactive, responsive explorer presenting all 2,688 Philippine mountain peaks with search, filtering, and sorting.
struct MountainsListView: View {
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
                            LinearGradient(gradient: Gradient(colors: [Color.orange, Color.red]), startPoint: .leading, endPoint: .trailing)
                        )
                        .shadow(color: (!viewModel.hasPendingReviews ? Color.gliderBlue : Color.red).opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
                
                // Island Group Filter Bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        FilterPill(title: "All (\(viewModel.publicPeaks.count))", assetImage: "philippines_icon", isSelected: viewModel.selectedIslandGroup == nil && viewModel.selectedRegion == nil) {
                            viewModel.resetFilters()
                        }
                        
                        ForEach(IslandGroup.allCases) { group in
                            FilterPill(title: group.rawValue, systemImage: group.systemImageName, assetImage: group.assetImageName, isSelected: viewModel.selectedIslandGroup == group) {
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
                    Text("Showing \(viewModel.filteredAndSortedPeaks.count) of \(viewModel.publicPeaks.count) Mountains")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                
                // Mountain List, Skeleton Loader & Empty Search State
                if viewModel.isLoading && viewModel.filteredAndSortedPeaks.isEmpty {
                    List {
                        ForEach(0..<10, id: \.self) { _ in
                            MountainSkeletonRowView()
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
            .conditionalSearchable(text: $viewModel.searchText, isPresented: $isSearchVisible, prompt: "Search by Name, Region (e.g. Region 6), or Details")
            .navigationTitle("Philippine Mountains")
            .navigationDestination(item: $selectedNewPeak) { peak in
                MountainDetailView(mountain: peak)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showAddCustomPeak = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("Contribute Mountain")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.gliderBlue)
                    }
                }
                
                // Sorting & Region Filters Menu
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            isSearchVisible = true
                        } label: {
                            Image(systemName: "magnifyingglass.circle.fill")
                                .font(.title3)
                                .foregroundColor(.gliderBlue)
                        }
                        
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
                                .foregroundColor(.gliderBlue)
                        }
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
            .task {
                if authViewModel.isAdmin {
                    await viewModel.fetchPendingGPSSubmissions()
                }
            }
        }
    }
}

struct FilterPill: View {
    let title: String
    var systemImage: String? = nil
    var assetImage: String? = nil
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.caption2)
                } else if let assetImage = assetImage {
                    Image(assetImage)
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                }
                Text(title)
            }
                .font(.caption)
                .fontWeight(isSelected ? .bold : .semibold)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.gliderBlue : Color.secondary.opacity(0.15))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
                .shadow(color: isSelected ? Color.gliderBlue.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
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

/// Shimmering skeleton loader row with a traveling highlight wave while mountains are downloading from Cloud Firestore.
struct MountainSkeletonRowView: View {
    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.45))
                .frame(width: 54, height: 54)
            
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.50))
                    .frame(width: 160, height: 16)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.38))
                    .frame(width: 95, height: 12)
            }
            
            Spacer()
            
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.42))
                .frame(width: 68, height: 36)
        }
        .padding(.vertical, 2)
        .modifier(SkeletonShimmerModifier())
    }
}

struct SkeletonShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1.0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.white.opacity(0.85),
                            Color.clear
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (phase * geometry.size.width * 2))
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
    }
}

#Preview {
    MountainsListView()
        .environmentObject(MountainsViewModel())
        .environmentObject(AuthViewModel())
}
