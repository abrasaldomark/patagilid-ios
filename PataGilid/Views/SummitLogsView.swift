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
    @EnvironmentObject var peaksViewModel: PeaksViewModel
    
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
            .searchable(text: $viewModel.searchText, prompt: "Search Mountain, Region, or Trail")
            .toolbar {
                if !viewModel.logs.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.gliderBlue)
                                    .font(.caption)
                                Text("\(viewModel.logs.filter { $0.didSummit }.count) summited")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gliderBlue)
                            }
                            
                            Menu {
                                Section(header: Text("Sort Order")) {
                                    ForEach(LogSortOrder.allCases, id: \.self) { order in
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
                                
                                Section(header: Text("Filter by Region")) {
                                    Button(action: { viewModel.selectRegion(nil) }) {
                                        Text("All Regions")
                                    }
                                    
                                    ForEach(viewModel.availableRegions(using: peaksViewModel.allPeaks), id: \.self) { region in
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
            }
        }
    }
    
    // MARK: - States
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.3)
                .tint(.gliderBlue)
            Text("Loading your logs...")
                .font(.subheadline)
                .foregroundColor(.secondary)
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
                Text("No Logs Yet")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("Open any mountain in the catalog and tap\n\"Log Climb\" to record your first ascent.")
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
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    FilterPill(title: "All (\(viewModel.logs.count))", isSelected: viewModel.selectedIslandGroup == nil && viewModel.selectedRegion == nil && viewModel.selectedOutcome == .all) {
                        withAnimation(.easeInOut) {
                            viewModel.resetFilters()
                        }
                    }
                    
                    ForEach(IslandGroup.allCases) { group in
                        FilterPill(title: group.rawValue, isSelected: viewModel.selectedIslandGroup == group) {
                            viewModel.selectIslandGroup(group)
                        }
                    }
                    
                    // Active Outcome Badge indicator
                    if viewModel.selectedOutcome != .all {
                        HStack(spacing: 4) {
                            Text(viewModel.selectedOutcome == .summited ? "Summited 🏆" : "Backed Out 🚫")
                                .lineLimit(1)
                            Image(systemName: "xmark.circle.fill")
                        }
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.gliderBlue.opacity(0.2))
                        .foregroundColor(.gliderBlue)
                        .clipShape(Capsule())
                        .onTapGesture {
                            viewModel.selectedOutcome = .all
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
                            viewModel.selectRegion(nil)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            .background(Color.secondary.opacity(0.06))
            
            let filteredLogs = viewModel.filteredAndSortedLogs(using: peaksViewModel.allPeaks)
            
            // Log Count Banner
            HStack {
                Text("Showing \(filteredLogs.count) of \(viewModel.logs.count) Climbs")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            
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
                        let mountain = peaksViewModel.allPeaks.first(where: { $0.id == log.mountainId }) ?? viewModel.mountain(for: log.mountainId)
                        NavigationLink(destination: SummitLogDetailView(log: log, mountain: mountain)) {
                            SummitLogRow(log: log, mountain: mountain)
                        }
                        .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                    .onDelete { offsets in
                        offsets.map { filteredLogs[$0] }.forEach { viewModel.delete($0) }
                    }
                }
                .listStyle(.insetGrouped)
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
                if let trail = log.trailName, !trail.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: (log.isTraverse == true) ? "point.bottomleft.forward.to.point.topright.scurvepath" : "point.forward.to.point.capsulepath")
                            .font(.caption2)
                        
                        if log.isTraverse == true, let exit = log.exitTrailName, !exit.isEmpty {
                            Text("\(trail) ➔ \(exit) (Traverse)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                        } else if log.isTraverse == true {
                            Text("\(trail) (Traverse)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                        } else {
                            Text("\(trail) (Back Trail)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                        }
                    }
                    .foregroundColor(log.isTraverse == true ? .purple : .blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(log.isTraverse == true ? Color.purple.opacity(0.1) : Color.blue.opacity(0.1))
                    .clipShape(Capsule())
                }
                
                outcomeBadge
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }
    
    private var outcomeIcon: some View {
        ZStack {
            Circle()
                .fill(log.didSummit ? Color.gliderBlue.opacity(0.12) : Color.red.opacity(0.10))
                .frame(width: 44, height: 44)
            Image(systemName: log.didSummit ? "mountain.2.fill" : "arrow.uturn.backward.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(log.didSummit ? .gliderBlue : .red)
        }
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

#Preview {
    SummitLogsView()
}
