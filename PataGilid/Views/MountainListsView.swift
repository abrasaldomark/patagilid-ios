//
//  MountainListsView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 8/15/26.
//

import SwiftUI
import SwiftData

enum ListSortOrder: String, CaseIterable {
    case nameAsc = "Ascending"
    case nameDesc = "Descending"
}

/// The "My Lists" hub tab — shows all of the user's personal mountain collections.
struct MountainListsView: View {
    var body: some View {
        NavigationStack {
            MountainListsContent()
                .navigationTitle("Lists")
        }
    }
}

// MARK: - Mountain Lists Content

struct MountainListsContent: View {
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
    @State private var sortOrder: ListSortOrder = .nameAsc

    private var filteredLists: [MountainList] {
        var result = lists
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let query = searchText.lowercased()
            result = result.filter { $0.name.lowercased().contains(query) }
        }
        
        switch sortOrder {
        case .nameAsc:
            return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameDesc:
            return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Wrap CountBanner in a real ScrollView to act as a stable layout anchor for the NavigationTitle.
            // Because it has a real size (>0), it does NOT cause the geometry calculation delay that the 0x0 hack caused!
            // Because it is a ScrollView, it prevents the NavigationTitle from disappearing when conditionalSearchable fires!
            ScrollView(.horizontal, showsIndicators: false) {
                CountBanner(
                    filteredCount: filteredLists.count,
                    totalCount: lists.count,
                    noun: "Lists"
                )
                .containerRelativeFrame(.horizontal)
            }
            .scrollDisabled(true)

            List {
                if lists.isEmpty {
                    emptyState
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else if filteredLists.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 52))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("No lists matched '\(searchText)'")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 300, alignment: .center)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredLists) { list in
                        NavigationLink(value: list) {
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
            }
            .listStyle(.plain)
            .conditionalSearchable(text: $searchText, isPresented: $isSearchVisible, prompt: "Search Lists")
        }
        .navigationDestination(for: MountainList.self) { list in
            MountainListDetailView(list: list)
        }
        .toolbar { toolbarContent }
        .task {
            try? await Task.sleep(nanoseconds: 300_000_000) // Let the navigation transition finish
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

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            SearchFilterToolbar(
                isSearchVisible: $isSearchVisible,
                onAdd: { showCreateSheet = true }
            ) {
                SortOrderMenuSection(
                    currentOrder: sortOrder,
                    onSelect: { sortOrder = $0 }
                )
            }
        }
    }


    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {

            Text("No Lists Yet")
                .font(.title2)
                .fontWeight(.bold)
            Text("Create your first mountain collection\nlike \"Luzon Trip\" or \"CAR Peaks\".")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 300, alignment: .center)
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
            .alignmentGuide(.listRowSeparatorLeading) { d in
                d[.leading]
            }

            Spacer()

            VStack(spacing: 2) {
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
    @FocusState private var isNameFocused: Bool

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
                        .focused($isNameFocused)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isNameFocused = true
            }
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
