//
//  SaveToListSheet.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 8/15/26.
//

import SwiftUI
import SwiftData

/// Bottom sheet shown when the user taps the bookmark icon in MountainDetailView.
/// Displays all personal lists as toggleable rows — tapping adds or removes the mountain.
struct SaveToListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var listsViewModel: MountainListsViewModel

    let mountainId: String

    @Query(sort: \MountainList.updatedAt, order: .reverse)
    private var lists: [MountainList]

    var body: some View {
        NavigationStack {
            Group {
                if lists.isEmpty {
                    emptyState
                } else {
                    listContent
                }
            }
            .navigationTitle("Save to List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - List Content

    private var listContent: some View {
        List(lists) { list in
            let isInList = list.mountainIds.contains(mountainId)
            Button {
                Task {
                    if isInList {
                        await listsViewModel.removeMountain(id: mountainId, from: list, in: modelContext)
                    } else {
                        await listsViewModel.addMountain(id: mountainId, to: list, in: modelContext)
                    }
                }
            } label: {
                HStack(spacing: 14) {
                    // Emoji badge
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gliderBlue.opacity(0.10))
                            .frame(width: 38, height: 38)
                        Text(list.emoji).font(.system(size: 18))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(list.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(list.mountainCount == 1 ? "1 mountain" : "\(list.mountainCount) mountains")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: isInList ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isInList ? .gliderBlue : .secondary)
                        .font(.title3)
                        .animation(.easeInOut(duration: 0.2), value: isInList)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("🏔️").font(.system(size: 48))
            Text("No Lists Yet")
                .font(.title3)
                .fontWeight(.bold)
            Text("Create a list first, then come back\nto save this mountain.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
