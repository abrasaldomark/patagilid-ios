//
//  MountainList.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 8/15/26.
//

import Foundation
import SwiftData
import FirebaseFirestore

/// A user-created named collection of mountain IDs (e.g. "Luzon Trip 2026", "CAR Mountains").
/// Persisted locally via SwiftData and synchronized with Cloud Firestore
/// under `users/{userId}/mountainLists/{listId}`.
@Model
final class MountainList: Identifiable {
    @Attribute(.unique) var id: String

    /// The authenticated Firebase user who owns this list.
    var userId: String

    /// User-provided list name (e.g. "Luzon Trip 2026").
    var name: String

    /// Optional emoji icon chosen by the user (e.g. "🏔️").
    var emoji: String

    /// Ordered array of `Mountain.id` values belonging to this list.
    var mountainIds: [String]

    /// Creation timestamp.
    var createdAt: Date

    /// Last-modified timestamp — used for ordering and future delta-sync.
    var updatedAt: Date

    // MARK: - Computed helpers (not persisted)

    var mountainCount: Int { mountainIds.count }

    var displayTitle: String {
        emoji.isEmpty ? name : "\(emoji) \(name)"
    }

    var contains: (String) -> Bool {
        { [mountainIds] id in mountainIds.contains(id) }
    }

    // MARK: - Init

    init(
        id: String = UUID().uuidString,
        userId: String,
        name: String,
        emoji: String = "🏔️",
        mountainIds: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.emoji = emoji
        self.mountainIds = mountainIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Firestore serialization

    /// Converts this model into a plain dictionary for Firestore writes.
    func toFirestoreData() -> [String: Any] {
        return [
            "id": id,
            "userId": userId,
            "name": name,
            "emoji": emoji,
            "mountainIds": mountainIds,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt)
        ]
    }

    /// Constructs a `MountainList` from a raw Firestore document snapshot.
    static func from(document: DocumentSnapshot) -> MountainList? {
        guard
            let data = document.data(),
            let userId = data["userId"] as? String,
            let name = data["name"] as? String
        else { return nil }

        let id = document.documentID
        let emoji = data["emoji"] as? String ?? "🏔️"
        let mountainIds = data["mountainIds"] as? [String] ?? []
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()

        return MountainList(
            id: id,
            userId: userId,
            name: name,
            emoji: emoji,
            mountainIds: mountainIds,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
