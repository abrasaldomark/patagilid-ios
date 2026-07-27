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
            .toolbar {
                if !viewModel.logs.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.emeraldGreen)
                                .font(.caption)
                            Text("\(viewModel.logs.filter { $0.didSummit }.count) summited")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.emeraldGreen)
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
                .tint(.emeraldGreen)
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
                .foregroundColor(.emeraldGreen.opacity(0.5))
                .padding()
                .background(Color.emeraldGreen.opacity(0.1))
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
        List {
            ForEach(viewModel.logs) { log in
                let mountain = viewModel.mountain(for: log.mountainId)
                NavigationLink(destination: SummitLogDetailView(log: log, mountain: mountain)) {
                    SummitLogRow(log: log, mountain: mountain)
                }
                .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
            .onDelete { offsets in
                offsets.map { viewModel.logs[$0] }.forEach { viewModel.delete($0) }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { viewModel.subscribe() }
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
                Text(mountain?.name ?? log.mountainId)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // Elevation · Date on a single line
                HStack(spacing: 5) {
                    if let elev = mountain?.elevationMASL {
                        Text("\(elev) MASL")
                            .fontWeight(.semibold)
                            .foregroundColor(.teal)
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
                
                outcomeBadge
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }
    
    private var outcomeIcon: some View {
        ZStack {
            Circle()
                .fill(log.didSummit ? Color.emeraldGreen.opacity(0.12) : Color.red.opacity(0.10))
                .frame(width: 44, height: 44)
            Image(systemName: log.didSummit ? "mountain.2.fill" : "arrow.uturn.backward.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(log.didSummit ? .emeraldGreen : .red)
        }
    }
    
    private var outcomeBadge: some View {
        Text(log.didSummit ? "Summited" : "Turned Back")
            .font(.caption2)
            .fontWeight(.black)
            .tracking(0.5)
            .foregroundColor(log.didSummit ? .emeraldGreen : .red)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(log.didSummit ? Color.emeraldGreen.opacity(0.1) : Color.red.opacity(0.08))
            .clipShape(Capsule())
    }
}

#Preview {
    SummitLogsView()
}
