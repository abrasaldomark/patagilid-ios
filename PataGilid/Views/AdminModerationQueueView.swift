//
//  AdminModerationQueueView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/28/26.
//

import SwiftUI
import FirebaseFirestore

struct AdminModerationQueueView: View {
    @EnvironmentObject var mountainsViewModel: MountainsViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var mountainToMerge: Mountain? = nil
    @State private var mountainToViewMap: Mountain? = nil
    @State private var showMergeSheet: Bool = false
    @State private var isProcessing: Bool = false
    @State private var actionFeedback: String? = nil
    @State private var selectedTab: Int = 0
    
    var body: some View {
        NavigationStack {
            Group {
                if !mountainsViewModel.hasPendingReviews {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gliderBlue)
                        
                        Text("Queue Empty!")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("You are completely caught up. Zero community mountain submissions or GPS calibrations waiting for review.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
                    VStack(spacing: 0) {
                        Picker("Queue Options", selection: $selectedTab) {
                            Text("Submitted Mountains").tag(0)
                            Text("GPS Calibrations").tag(1)
                        }
                        .pickerStyle(.segmented)
                        .padding()
                        .background(Color(.systemGroupedBackground))
                        
                        if selectedTab == 0 {
                            if mountainsViewModel.pendingReviewPeaks.isEmpty {
                                emptyTabMessage(title: "No Submitted Mountains", message: "There are no community mountains pending review.")
                            } else {
                                List {
                                    Section(header: Text("Pending Submitted Mountains (\(mountainsViewModel.pendingReviewPeaks.count))"),
                                            footer: Text("Approved mountains go live instantly on the public list. Merged mountains re-link contributor logs to an official entry and remove the duplicate.")) {
                                        ForEach(mountainsViewModel.pendingReviewPeaks) { peak in
                                            pendingPeakCard(for: peak)
                                                .padding(.vertical, 4)
                                        }
                                    }
                                }
                                .listStyle(.insetGrouped)
                            }
                        } else {
                            if mountainsViewModel.pendingGPSPeaks.isEmpty {
                                emptyTabMessage(title: "No GPS Calibrations", message: "There are no GPS calibrations pending review.")
                            } else {
                                List {
                                    Section(header: Text("Pending GPS Calibrations (\(mountainsViewModel.pendingGPSPeaks.count))"),
                                            footer: Text("Approved coordinates immediately calibrate the official mountain entry and grant a verified community badge nationwide via Delta-Sync.")) {
                                        ForEach(mountainsViewModel.pendingGPSPeaks) { mountain in
                                            gpsSubmissionCard(for: mountain)
                                        }
                                    }
                                }
                                .listStyle(.insetGrouped)
                            }
                        }
                    }
                }
            }
            .navigationTitle("🛡️ Moderation Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(item: $mountainToMerge) { duplicate in
                MergeMountainSelectionSheet(duplicatePeak: duplicate) { target in
                    Task {
                        await handleMerge(duplicate: duplicate, target: target)
                    }
                }
                .environmentObject(mountainsViewModel)
            }
            .sheet(item: $mountainToViewMap) { targetMountain in
                MountainMapView(mountain: targetMountain)
                    .environmentObject(authViewModel)
            }
            .overlay {
                if isProcessing {
                    ZStack {
                        Color.black.opacity(0.35).ignoresSafeArea()
                        ProgressView("Processing Moderation...")
                            .padding(20)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .shadow(radius: 8)
                    }
                }
            }
            .alert(item: Binding<AlertFeedback?>(
                get: { actionFeedback.map { AlertFeedback(message: $0) } },
                set: { _ in actionFeedback = nil }
            )) { feedback in
                Alert(title: Text("Moderation Success"), message: Text(feedback.message), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    // MARK: - Empty States
    
    @ViewBuilder
    private func emptyTabMessage(title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundColor(.green.opacity(0.6))
            
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Cards
    
    @ViewBuilder
    private func pendingPeakCard(for peak: Mountain) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Info
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(peak.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right.circle.fill")
                            .foregroundColor(.gliderBlue)
                            .font(.caption)
                        Text("\(peak.elevationMASL) MASL")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.summitSteel)
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(peak.islandGroup.rawValue)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("📍 \(peak.region)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Difficulty")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(peak.difficultyLevel)
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .cornerRadius(6)
                }
            }
            
            // Description & Contributor details
            VStack(alignment: .leading, spacing: 6) {
                Text(peak.descriptionText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                
                if let contributorName = peak.displayContributorName {
                    HStack(spacing: 4) {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.purple)
                            .font(.caption2)
                        Text("Submitted by: \(contributorName)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.purple)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.06))
            .cornerRadius(8)
            // View Map Button
            Button {
                mountainToViewMap = peak
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "map.fill")
                    Text("View Map")
                }
                .font(.caption)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.secondary.opacity(0.15))
                .foregroundColor(.primary)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            // Actions Row
            HStack(spacing: 12) {
                Button {
                    Task { await handleDecline(peak) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                        Text("Reject")
                    }
                    .font(.caption)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.15))
                    .foregroundColor(.red)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button {
                    mountainToMerge = peak
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.merge")
                        Text("Merge")
                    }
                    .font(.caption)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button {
                    Task { await handleApprove(peak) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Approve")
                    }
                    .font(.caption)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.gliderBlue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    @ViewBuilder
    private func gpsSubmissionCard(for mountain: Mountain) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mountain.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text("📍 \(mountain.pendingRegion ?? mountain.region)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("GPS Proposal")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gliderBlue.opacity(0.15))
                    .foregroundColor(.gliderBlue)
                    .cornerRadius(6)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.orange)
                    Text(String(format: "%.6f, %.6f", mountain.pendingLatitude ?? 0.0, mountain.pendingLongitude ?? 0.0))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                if let contributorName = mountain.displayPendingContributorName {
                    HStack(spacing: 4) {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.purple)
                            .font(.caption2)
                        Text("Submitted by: \(contributorName)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.purple)
                    }
                    .padding(.top, 2)
                }
                
                if mountain.pendingVerifications > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                            .font(.caption2)
                        Text("⭐️ Upvoted by \(mountain.pendingVerifications) community mountaineer\(mountain.pendingVerifications == 1 ? "" : "s")")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.06))
            .cornerRadius(8)
            
            // View Map Button
            Button {
                mountainToViewMap = mountain
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "map.fill")
                    Text("View Map")
                }
                .font(.caption)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.secondary.opacity(0.15))
                .foregroundColor(.primary)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Button {
                    Task { await handleRejectGPS(mountain) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                        Text("Reject")
                    }
                    .font(.caption)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.15))
                    .foregroundColor(.red)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button {
                    Task { await handleApproveGPS(mountain) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Approve")
                    }
                    .font(.caption)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.gliderBlue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Async Moderation Handlers
    
    private func handleApprove(_ mountain: Mountain) async {
        isProcessing = true
        do {
            try await mountainsViewModel.approveMountain(mountain)
            actionFeedback = "✅ \(mountain.name) has been approved and is now live nationwide in PataGilid!"
        } catch {
            actionFeedback = "⚠️ Failed to approve: \(error.localizedDescription)"
        }
        isProcessing = false
    }
    
    private func handleDecline(_ mountain: Mountain) async {
        isProcessing = true
        do {
            try await mountainsViewModel.declineMountain(mountain)
            actionFeedback = "🗑️ \(mountain.name) was rejected and removed from the review queue."
        } catch {
            actionFeedback = "⚠️ Failed to decline: \(error.localizedDescription)"
        }
        isProcessing = false
    }
    
    private func handleMerge(duplicate: Mountain, target: Mountain) async {
        isProcessing = true
        do {
            try await mountainsViewModel.mergeMountain(duplicate: duplicate, into: target)
            actionFeedback = "🔀 Merged '\(duplicate.name)' into official '\(target.name)'. All user climb logs re-linked safely!"
        } catch {
            actionFeedback = "⚠️ Failed to merge: \(error.localizedDescription)"
        }
        isProcessing = false
    }
    
    private func handleApproveGPS(_ mountain: Mountain) async {
        isProcessing = true
        do {
            try await mountainsViewModel.approveGPS(for: mountain)
            actionFeedback = "✅ GPS coordinates for '\(mountain.name)' approved & broadcasted nationwide via Delta-Sync!"
        } catch {
            actionFeedback = "⚠️ Failed to approve GPS: \(error.localizedDescription)"
        }
        isProcessing = false
    }
    
    private func handleRejectGPS(_ mountain: Mountain) async {
        isProcessing = true
        do {
            try await mountainsViewModel.declineGPS(for: mountain)
            actionFeedback = "🗑️ GPS submission rejected."
        } catch {
            actionFeedback = "⚠️ Failed to reject GPS: \(error.localizedDescription)"
        }
        isProcessing = false
    }
}

// MARK: - Helper Types & Sheets

struct AlertFeedback: Identifiable {
    let id = UUID()
    let message: String
}

struct MergeMountainSelectionSheet: View {
    let duplicatePeak: Mountain
    let onSelectTarget: (Mountain) -> Void
    
    @EnvironmentObject var mountainsViewModel: MountainsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    
    var filteredPublicPeaks: [Mountain] {
        if searchText.isEmpty {
            return mountainsViewModel.publicPeaks.prefix(50).map { $0 }
        } else {
            return mountainsViewModel.publicPeaks.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.region.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Merging Duplicate Entry:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(duplicatePeak.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    Text("Select the canonical, official PataGilid mountain below to merge into. All hike logs pointing to this duplicate will be re-linked without data loss.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08))
                
                List {
                    Section(header: Text("Official Mountain on List")) {
                        ForEach(filteredPublicPeaks) { target in
                            Button {
                                onSelectTarget(target)
                                dismiss()
                                } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(target.name)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                        Text("\(target.elevationMASL) MASL • \(target.region)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "checkmark.circle")
                                        .foregroundColor(.blue)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listStyle(.plain)
                .searchable(text: $searchText, prompt: "Search official mountain name...")
            }
            .navigationTitle("🔀 Select Merge Target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
