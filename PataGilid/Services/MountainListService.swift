//
//  MountainListService.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 8/15/26.
//

import Foundation
import SwiftData
import FirebaseAuth
import FirebaseFirestore
import Combine

/// Handles all Firestore read/write operations for a user's personal mountain lists,
/// and keeps the local SwiftData cache in sync. Mirrors MountainListRepository on Android.
class MountainListService: ObservableObject {
    static let shared = MountainListService()

    private let db = Firestore.firestore()

    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    private func listsCollection(for uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("mountainLists")
    }

    // MARK: - Sync from Firestore

    /// Fetches all lists from Firestore and upserts them into the local SwiftData context.
    @MainActor
    func syncFromFirestore(in modelContext: ModelContext) async {
        guard let uid = currentUserId else { return }
        do {
            let snapshot = try await listsCollection(for: uid).getDocuments()
            
            // Delete all existing lists for the user and re-insert to ensure perfect sync
            try? modelContext.delete(model: MountainList.self, where: #Predicate { $0.userId == uid })
            
            for doc in snapshot.documents {
                guard let remote = MountainList.from(document: doc) else { continue }
                modelContext.insert(remote)
            }
            try? modelContext.save()
            print("✅ [MountainListService] Synced \(snapshot.documents.count) lists from Firestore.")
        } catch {
            print("🌐 [MountainListService] Offline or sync failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Create

    /// Creates a new named list in Firestore and inserts it into SwiftData.
    @MainActor
    func createList(name: String, emoji: String = "🏔️", in modelContext: ModelContext) async throws {
        guard let uid = currentUserId else { throw ServiceError.notSignedIn }
        let docRef = listsCollection(for: uid).document()
        let list = MountainList(id: docRef.documentID, userId: uid, name: name.trimmingCharacters(in: .whitespaces), emoji: emoji)
        try await docRef.setData(list.toFirestoreData())
        modelContext.insert(list)
        try? modelContext.save()
        print("✅ [MountainListService] Created list '\(list.displayTitle)' (\(list.id))")
    }

    // MARK: - Rename

    /// Updates the name and emoji of an existing list.
    @MainActor
    func renameList(_ list: MountainList, newName: String, newEmoji: String, in modelContext: ModelContext) async throws {
        guard let uid = currentUserId else { throw ServiceError.notSignedIn }
        let now = Date()
        try await listsCollection(for: uid).document(list.id).updateData([
            "name": newName.trimmingCharacters(in: .whitespaces),
            "emoji": newEmoji,
            "updatedAt": Timestamp(date: now)
        ])
        list.name = newName.trimmingCharacters(in: .whitespaces)
        list.emoji = newEmoji
        list.updatedAt = now
        try? modelContext.save()
    }

    // MARK: - Delete

    /// Permanently deletes a list from Firestore and removes it from SwiftData.
    @MainActor
    func deleteList(_ list: MountainList, in modelContext: ModelContext) async throws {
        guard let uid = currentUserId else { throw ServiceError.notSignedIn }
        try await listsCollection(for: uid).document(list.id).delete()
        modelContext.delete(list)
        try? modelContext.save()
        print("🗑️ [MountainListService] Deleted list \(list.id)")
    }

    // MARK: - Add / Remove Mountain

    /// Adds a mountain ID to the list (idempotent via Firestore arrayUnion).
    @MainActor
    func addMountain(id mountainId: String, to list: MountainList, in modelContext: ModelContext) async throws {
        guard let uid = currentUserId else { throw ServiceError.notSignedIn }
        let now = Date()
        try await listsCollection(for: uid).document(list.id).updateData([
            "mountainIds": FieldValue.arrayUnion([mountainId]),
            "updatedAt": Timestamp(date: now)
        ])
        if !list.mountainIds.contains(mountainId) {
            list.mountainIds.append(mountainId)
        }
        list.updatedAt = now
        try? modelContext.save()
    }

    /// Removes a mountain ID from the list via Firestore arrayRemove.
    @MainActor
    func removeMountain(id mountainId: String, from list: MountainList, in modelContext: ModelContext) async throws {
        guard let uid = currentUserId else { throw ServiceError.notSignedIn }
        let now = Date()
        try await listsCollection(for: uid).document(list.id).updateData([
            "mountainIds": FieldValue.arrayRemove([mountainId]),
            "updatedAt": Timestamp(date: now)
        ])
        list.mountainIds.removeAll { $0 == mountainId }
        list.updatedAt = now
        try? modelContext.save()
    }

    // MARK: - Errors

    enum ServiceError: LocalizedError {
        case notSignedIn
        var errorDescription: String? {
            switch self {
            case .notSignedIn: return "You must be signed in to manage your mountain lists."
            }
        }
    }
}
