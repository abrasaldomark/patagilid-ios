//
//  MountainListsView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 8/15/26.
//

import SwiftUI
import SwiftData

/// The "My Lists" hub tab — shows all of the user's personal mountain collections.
struct MountainListsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var listsViewModel: MountainListsViewModel

    @Query(sort: \MountainList.updatedAt, order: .reverse)
    private var lists: [MountainList]

    @State private var showCreateSheet = false
    @State private var editTarget: MountainList? = nil
    @State private var deleteTarget: MountainList? = nil
    @State private var showDeleteAlert = false
    @State private var showErrorAlert = false
    @State private var deleteAlertTitle = ""
    @State private var isSearchVisible: Bool = false
    @State private var searchText: String = ""

    private var filteredLists: [MountainList] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return lists
        }
        let query = searchText.lowercased()
        return lists.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Count Banner
                CountBanner(
                    filteredCount: filteredLists.count,
                    totalCount: lists.count,
                    noun: "Lists"
                )

                if lists.isEmpty {
                    emptyState
                } else if filteredLists.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 52))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("No lists matched '\(searchText)'")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    listContent
                }
            }
            .conditionalSearchable(text: $searchText, isPresented: $isSearchVisible, prompt: "Search Lists")
            .navigationTitle("My Lists")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarContent }
            .task {
                await listsViewModel.sync(in: modelContext)
            }
            .sheet(isPresented: $showCreateSheet) {
                ListNameSheet(title: "New List", initialName: "", initialEmoji: "🏔️") { name, emoji in
                    Task { await listsViewModel.createList(name: name, emoji: emoji, in: modelContext) }
                }
            }
            .sheet(item: $editTarget) { target in
                ListNameSheet(title: "Rename List", initialName: target.name, initialEmoji: target.emoji) { name, emoji in
                    Task { await listsViewModel.renameList(target, newName: name, newEmoji: emoji, in: modelContext) }
                }
            }
            .alert(deleteAlertTitle, isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let target = deleteTarget {
                        Task { await listsViewModel.deleteList(target, in: modelContext) }
                    }
                    deleteTarget = nil
                }
                Button("Cancel", role: .cancel) { deleteTarget = nil }
            } message: {
                Text("This will permanently remove the list and all its saved mountains. Your climb logs are unaffected.")
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { listsViewModel.clearError() }
            } message: {
                Text(listsViewModel.errorMessage ?? "")
            }
            .onChange(of: listsViewModel.errorMessage) { _, newValue in
                showErrorAlert = newValue != nil
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 12) {
                if !lists.isEmpty {
                    Button {
                        isSearchVisible = true
                    } label: {
                        Image(systemName: "magnifyingglass.circle.fill")
                            .font(.title3)
                            .foregroundColor(.gliderBlue)
                    }
                }

                Button {
                    showCreateSheet = true
                } label: {
                    Text("Add List")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
            }
        }
    }

    // MARK: - List Content

    private var listContent: some View {
        List {
            ForEach(filteredLists) { list in
                NavigationLink(destination: MountainListDetailView(list: list)) {
                    MountainListRow(list: list)
                }
                .listRowSeparator(.visible)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        deleteTarget = list
                        deleteAlertTitle = "Delete \"\(list.name)\"?"
                        showDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        editTarget = list
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    .tint(.gliderBlue)
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await listsViewModel.sync(in: modelContext)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("🏔️")
                .font(.system(size: 60))
            Text("No Lists Yet")
                .font(.title2)
                .fontWeight(.bold)
            Text("Create your first mountain collection\nlike \"Luzon Trip\" or \"CAR Peaks\".")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}


// MARK: - List Row

struct MountainListRow: View {
    let list: MountainList

    var body: some View {
        HStack(spacing: 14) {
            // Emoji badge — matches MountainHeaderImageView thumbnail sizing
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gliderBlue.opacity(0.10))
                    .frame(width: 52, height: 52)
                Text(list.emoji)
                    .font(.system(size: 24))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(list.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(1)
                Text(list.mountainCount == 1 ? "1 mountain" : "\(list.mountainCount) mountains")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(list.mountainCount)")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
                Text("peaks")
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
}

// MARK: - Create / Rename Sheet

struct ListNameSheet: View {
    let title: String
    @State var initialName: String
    @State var initialEmoji: String
    let onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var emoji: String = "🏔️"

    private let quickEmojis = ["🏔️", "⛰️", "🌋", "🗻", "🌿", "🧭", "🎒", "🥾", "🏕️", "📍", "⭐", "❤️"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Icon") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(quickEmojis, id: \.self) { e in
                                emojiButton(e)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Name") {
                    TextField("e.g. Luzon Trip 2026", text: $name)
                        .autocorrectionDisabled(false)
                        .textInputAutocapitalization(.words)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(name.trimmingCharacters(in: .whitespaces), emoji)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear {
            name = initialName
            emoji = initialEmoji
        }
    }

    // Extracted to help the type-checker
    @ViewBuilder
    private func emojiButton(_ e: String) -> some View {
        Button {
            emoji = e
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(emoji == e ? Color.gliderBlue.opacity(0.15) : Color(UIColor.systemGroupedBackground))
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(emoji == e ? Color.gliderBlue : Color.clear, lineWidth: 2)
                    )
                Text(e).font(.system(size: 22))
            }
        }
        .buttonStyle(.plain)
    }
}
