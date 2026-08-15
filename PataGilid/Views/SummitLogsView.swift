//
//  SummitLogsView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/28/26.
//

import SwiftUI

/// The hiker's personal activity feed — a chronological list of recorded climb attempts.
struct SummitLogsView: View {
    @StateObject private var viewModel = SummitLogsViewModel()
    @EnvironmentObject var mountainsViewModel: MountainsViewModel
    @State private var isSearchVisible: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.errorMessage {
                    errorView(error)
                } else if viewModel.logs.isEmpty {
                    emptyView
                } else {
                    logList
                }
            }
            .navigationTitle("My Summit Logs")
            .conditionalSearchable(text: $viewModel.searchText, isPresented: $isSearchVisible, prompt: "Search Mountain, Region, or Trail")
            .toolbar {
                if !viewModel.logs.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        SearchFilterToolbar(isSearchVisible: $isSearchVisible) {
                            SortOrderMenuSection(
                                currentOrder: viewModel.sortOrder,
                                onSelect: { viewModel.sortOrder = $0 }
                            )
                            
                            Section(header: Text("Filter by Outcome")) {
                                ForEach(LogOutcomeFilter.allCases, id: \.self) { outcome in
                                    Button(action: { viewModel.selectedOutcome = outcome }) {
                                        HStack {
                                            Text(outcome.rawValue)
                                            if viewModel.selectedOutcome == outcome {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            }
                            
                            RegionFilterMenuSection(
                                availableRegions: viewModel.availableRegions(using: mountainsViewModel.allPeaks),
                                selectedRegion: viewModel.selectedRegion,
                                onSelectRegion: { viewModel.selectRegion($0) }
                            )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - States
    
    private var loadingView: some View {
        VStack(spacing: 0) {
            // Skeleton Filter Bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(0..<4, id: \.self) { _ in
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(width: 85, height: 30)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            .background(Color.secondary.opacity(0.06))
            
            // Skeleton List
            List {
                ForEach(0..<6, id: \.self) { _ in
                    SummitLogSkeletonRow()
                        .listRowSeparator(.visible)
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                }
            }
            .listStyle(.plain)
            .disabled(true)
        }
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundColor(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "mountain.2")
                .font(.system(size: 64))
                .foregroundColor(.gliderBlue.opacity(0.5))
                .padding()
                .background(Color.gliderBlue.opacity(0.1))
                .clipShape(Circle())
            
            VStack(spacing: 8) {
                Text("Akyat na!")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("Open any mountain on the list and tap\n\"Add Climb\" to record your first ascent.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }
        }
    }
    
    // MARK: - Log List
    
    private var logList: some View {
        VStack(spacing: 0) {
            // Island Group Filter Bar
            IslandGroupFilterBar(
                allCount: viewModel.logs.count,
                selectedIslandGroup: viewModel.selectedIslandGroup,
                selectedRegion: viewModel.selectedRegion,
                isAllSelected: viewModel.selectedIslandGroup == nil && viewModel.selectedRegion == nil && viewModel.selectedOutcome == .all,
                onResetFilters: {
                    withAnimation(.easeInOut) {
                        viewModel.resetFilters()
                    }
                },
                onSelectIslandGroup: { viewModel.selectIslandGroup($0) },
                onClearRegion: { viewModel.selectRegion(nil) }
            ) {
                // Active Outcome Badge indicator (unique to My Climbs)
                if viewModel.selectedOutcome != .all {
                    DismissableBadge(
                        label: viewModel.selectedOutcome == .summited ? "Summited 🏆" : "Backed Out 🚫",
                        color: .gliderBlue,
                        onDismiss: { viewModel.selectedOutcome = .all }
                    )
                }
            }
            
            let filteredLogs = viewModel.filteredAndSortedLogs(using: mountainsViewModel.allPeaks)
            
            // Log Count Banner
            CountBanner(
                filteredCount: filteredLogs.count,
                totalCount: viewModel.logs.count,
                noun: "Climbs"
            )
            
            if filteredLogs.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 52))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text(viewModel.searchText.isEmpty ? "No climbs match active filters" : "No climbs matched '\(viewModel.searchText)'")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Button("Reset Filters") {
                        viewModel.resetFilters()
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.gliderBlue)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredLogs) { log in
                        let mountain = mountainsViewModel.allPeaks.first(where: { $0.id == log.mountainId }) ?? viewModel.mountain(for: log.mountainId)
                        NavigationLink(destination: SummitLogDetailView(log: log, mountain: mountain)) {
                            SummitLogRow(log: log, mountain: mountain)
                        }
                        .listRowSeparator(.visible)
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    }
                    .onDelete { offsets in
                        offsets.map { filteredLogs[$0] }.forEach { viewModel.delete($0) }
                    }
                }
                .listStyle(.plain)
                .refreshable { viewModel.subscribe() }
            }
        }
    }
}

// MARK: - Row Component

/// A single log entry row — fixed single-line date, full region on its own line.
struct SummitLogRow: View {
    let log: HikeLog
    let mountain: Mountain?
    
    var body: some View {
        HStack(spacing: 14) {
            outcomeIcon
            
            VStack(alignment: .leading, spacing: 5) {
                // Mountain name
                Text(mountain?.name ?? (log.mountainId.contains("_") ? log.mountainId.components(separatedBy: "_").dropFirst().first?.replacingOccurrences(of: "-", with: " ").capitalized ?? "Custom Mountain" : "Unlisted Local Mountain"))
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // Elevation · Date on a single line
                HStack(spacing: 5) {
                    if let elev = mountain?.elevationMASL {
                        Text("\(elev) MASL")
                            .fontWeight(.semibold)
                            .foregroundColor(.summitSteel)
                        Text("·").foregroundColor(.secondary)
                    }
                    Text(log.dateTimeStart, format: .dateTime.day().month(.abbreviated).year())
                        .foregroundColor(.secondary)
                }
                .font(.caption)
                .lineLimit(1)
                
                // Region — full width, no truncation
                if let region = mountain?.region {
                    Text(region)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Optional Custom Trail / Traverse Route Badge
                if !log.trailName.isEmpty {
                    HStack(spacing: 4) {
                        let isCircuit = log.routeType == "Circuit"
                        let isTraverse = log.routeType == "Traverse"
                        let iconName = isCircuit ? "arrow.triangle.2.circlepath" : (isTraverse ? "point.bottomleft.forward.to.point.topright.scurvepath" : "point.forward.to.point.capsulepath")
                        let color: Color = isCircuit ? .orange : (isTraverse ? .purple : .blue)
                        
                        Image(systemName: iconName)
                            .font(.caption2)
                        
                        if isTraverse, !log.exitTrailName.isEmpty {
                            Text("\(log.trailName) ➔ \(log.exitTrailName) (Traverse)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                        } else if isTraverse {
                            Text("\(log.trailName) (Traverse)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                        } else if isCircuit {
                            Text("\(log.trailName) (Circuit)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                        } else {
                            Text("\(log.trailName) (Back Trail)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                        }
                    }
                    .foregroundColor(log.routeType == "Circuit" ? .orange : (log.routeType == "Traverse" ? .purple : .blue))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background((log.routeType == "Circuit" ? Color.orange : (log.routeType == "Traverse" ? Color.purple : Color.blue)).opacity(0.1))
                    .clipShape(Capsule())
                }
                
                outcomeBadge
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }
    
    private var outcomeIcon: some View {
        MountainHeaderImageView(
            mountain: mountain ?? Mountain(
                id: log.mountainId,
                name: log.mountainId.contains("_") ? log.mountainId.components(separatedBy: "_").dropFirst().first?.replacingOccurrences(of: "-", with: " ").capitalized ?? "Custom Mountain" : "Unlisted Local Mountain",
                description: "",
                elevationMASL: 0,
                latitude: 0.0,
                longitude: 0.0,
                region: "",
                islandGroup: .luzon,
                difficultyLevel: "",
                trailClass: ""
            ),
            isThumbnail: true
        )
    }
    
    private var outcomeBadge: some View {
        Text(log.didSummit ? "Summited" : "Backed Out")
            .font(.caption2)
            .fontWeight(.black)
            .tracking(0.5)
            .foregroundColor(log.didSummit ? .gliderBlue : .red)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(log.didSummit ? Color.gliderBlue.opacity(0.1) : Color.red.opacity(0.08))
            .clipShape(Capsule())
    }
}

// MARK: - Skeleton Row Component

/// A shimmering placeholder row simulating a summit log entry while loading.
struct SummitLogSkeletonRow: View {
    @State private var isPulsing = false
    
    var body: some View {
        HStack(spacing: 14) {
            // Outcome Icon Skeleton
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 52, height: 52)
            
            VStack(alignment: .leading, spacing: 8) {
                // Mountain Name Skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 170, height: 16)
                
                // Elevation & Date Skeleton
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 120, height: 12)
                
                // Region Skeleton
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 210, height: 12)
                
                // Outcome Badge Skeleton
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 76, height: 20)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .opacity(isPulsing ? 0.35 : 0.85)
        .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true), value: isPulsing)
        .onAppear {
            isPulsing = true
        }
    }
}

#Preview("Summit Logs") {
    SummitLogsView()
}

#Preview("Skeleton Loading") {
    ZStack {
        Color(uiColor: .systemGroupedBackground)
            .ignoresSafeArea()
        
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(0..<4, id: \.self) { _ in
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(width: 85, height: 30)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            .background(Color.secondary.opacity(0.06))
            
            List {
                ForEach(0..<6, id: \.self) { _ in
                    SummitLogSkeletonRow()
                        .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
            }
            .listStyle(.insetGrouped)
            .disabled(true)
        }
    }
}
