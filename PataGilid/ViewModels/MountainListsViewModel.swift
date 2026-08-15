//
//  MountainListsViewModel.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 8/15/26.
//

import SwiftUI
import SwiftData
import Combine

/// ViewModel managing the user's personal mountain lists on iOS.
/// Handles Firestore sync, CRUD operations, and "Save to List" sheet state.
final class MountainListsViewModel: ObservableObject {

    // MARK: - State

    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    /// Controls the "Save to List" bottom sheet from MountainDetailView.
    @Published var showSaveToListSheet: Bool = false
    @Published var mountainIdToSave: String? = nil

    private let service = MountainListService.shared

    // MARK: - Sync

    /// Fetches all lists from Firestore and updates SwiftData.
    @MainActor
    func sync(in modelContext: ModelContext) async {
        isLoading = true
        await service.syncFromFirestore(in: modelContext)
        isLoading = false
    }

    // MARK: - Create

    @MainActor
    func createList(name: String, emoji: String = "🏔️", in modelContext: ModelContext) async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        do {
            try await service.createList(name: name, emoji: emoji, in: modelContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Rename

    @MainActor
    func renameList(_ list: MountainList, newName: String, newEmoji: String, in modelContext: ModelContext) async {
        guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        do {
            try await service.renameList(list, newName: newName, newEmoji: newEmoji, in: modelContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete

    @MainActor
    func deleteList(_ list: MountainList, in modelContext: ModelContext) async {
        do {
            try await service.deleteList(list, in: modelContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Add / Remove Mountain

    @MainActor
    func addMountain(id mountainId: String, to list: MountainList, in modelContext: ModelContext) async {
        do {
            try await service.addMountain(id: mountainId, to: list, in: modelContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func removeMountain(id mountainId: String, from list: MountainList, in modelContext: ModelContext) async {
        do {
            try await service.removeMountain(id: mountainId, from: list, in: modelContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Save-to-List Sheet Trigger

    /// Called from MountainDetailView to open the "Save to List" sheet for a specific mountain.
    @MainActor
    func openSaveToListSheet(for mountainId: String) {
        mountainIdToSave = mountainId
        showSaveToListSheet = true
    }

    @MainActor
    func clearError() {
        errorMessage = nil
    }
}
