//
//  AdminModerationQueueView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/28/26.
//

import SwiftUI

struct AdminModerationQueueView: View {
    @EnvironmentObject var peaksViewModel: PeaksViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var mountainToMerge: Mountain? = nil
    @State private var showMergeSheet: Bool = false
    @State private var isProcessing: Bool = false
    @State private var actionFeedback: String? = nil
    
    var body: some View {
        NavigationStack {
            Group {
                if peaksViewModel.pendingReviewPeaks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gliderBlue)
                        
                        Text("Queue Empty!")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("You are completely caught up. Zero community mountain submissions waiting for verification.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
                    List {
                        Section(header: Text("Pending Community Submissions (\(peaksViewModel.pendingReviewPeaks.count))"),
                                footer: Text("Approved peaks go live instantly in the public catalog. Merged peaks re-link contributor logs to an official entry and remove the duplicate.")) {
                            ForEach(peaksViewModel.pendingReviewPeaks) { peak in
                                pendingPeakCard(for: peak)
                                    .padding(.vertical, 4)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
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
                .environmentObject(peaksViewModel)
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
                Text(peak.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                
                if let email = peak.contributorEmail {
                    HStack(spacing: 4) {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.purple)
                            .font(.caption2)
                        Text("Submitted by: \(email)")
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
            
            // Actions Row
            HStack(spacing: 12) {
                // Reject Button
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
                
                // Merge Button
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
                
                // Approve Button
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
    
    // MARK: - Async Moderation Handlers
    
    private func handleApprove(_ mountain: Mountain) async {
        isProcessing = true
        do {
            try await peaksViewModel.approveMountain(mountain)
            actionFeedback = "✅ \(mountain.name) has been approved and is now live nationwide in PataGilid!"
        } catch {
            actionFeedback = "⚠️ Failed to approve: \(error.localizedDescription)"
        }
        isProcessing = false
    }
    
    private func handleDecline(_ mountain: Mountain) async {
        isProcessing = true
        do {
            try await peaksViewModel.declineMountain(mountain)
            actionFeedback = "🗑️ \(mountain.name) was rejected and removed from the review queue."
        } catch {
            actionFeedback = "⚠️ Failed to decline: \(error.localizedDescription)"
        }
        isProcessing = false
    }
    
    private func handleMerge(duplicate: Mountain, target: Mountain) async {
        isProcessing = true
        do {
            try await peaksViewModel.mergeMountain(duplicate: duplicate, into: target)
            actionFeedback = "🔀 Merged '\(duplicate.name)' into official '\(target.name)'. All user climb logs re-linked safely!"
        } catch {
            actionFeedback = "⚠️ Failed to merge: \(error.localizedDescription)"
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
    
    @EnvironmentObject var peaksViewModel: PeaksViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    
    var filteredPublicPeaks: [Mountain] {
        if searchText.isEmpty {
            return peaksViewModel.publicPeaks.prefix(50).map { $0 }
        } else {
            return peaksViewModel.publicPeaks.filter {
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
                    Text("Select the canonical, official PataGilid peak below to merge into. All hike logs pointing to this duplicate will be re-linked without data loss.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08))
                
                List {
                    Section(header: Text("Official Catalog Target")) {
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
                .searchable(text: $searchText, prompt: "Search official peak name...")
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
