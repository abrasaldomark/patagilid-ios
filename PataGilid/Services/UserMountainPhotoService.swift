//
//  UserMountainPhotoService.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 8/3/26.
//

import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

/// Manages private, user-specific mountain cover photo URLs saved to the individual hiker's account and Google Drive album.
/// These cover photos are completely separate from the shared public catalog and only appear when the contributor is logged into their account.
@MainActor
class UserMountainPhotoService: ObservableObject {
    static let shared = UserMountainPhotoService()
    
    /// Map of mountain ID -> user's private Google Drive photo URL
    @Published private(set) var customPhotos: [String: String] = [:]
    
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var firestoreListener: ListenerRegistration?
    
    private init() {
        // Observe auth state so that when a user logs in or switches accounts, only their photos are loaded
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] (_, user) in
            Task { @MainActor in
                self?.handleUserChange(user: user)
            }
        }
    }
    
    deinit {
        if let authHandle = authHandle {
            Auth.auth().removeStateDidChangeListener(authHandle)
        }
        firestoreListener?.remove()
    }
    
    private func handleUserChange(user: FirebaseAuth.User?) {
        firestoreListener?.remove()
        firestoreListener = nil
        
        guard let userId = user?.uid else {
            customPhotos = [:]
            return
        }
        
        // Load immediately from local cache for instant UI rendering
        let cacheKey = "user_mountain_photos_\(userId)"
        if let cached = UserDefaults.standard.dictionary(forKey: cacheKey) as? [String: String] {
            self.customPhotos = cached
        } else {
            self.customPhotos = [:]
        }
        
        // Listen to Firestore real-time updates from the user's private subcollection
        let db = Firestore.firestore()
        firestoreListener = db.collection("users").document(userId).collection("mountainPhotos").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let documents = snapshot?.documents else { return }
            
            var updatedMap: [String: String] = [:]
            for doc in documents {
                let mountainId = doc.documentID
                if let photoUrl = doc.data()["photoUrl"] as? String {
                    updatedMap[mountainId] = photoUrl
                }
            }
            
            Task { @MainActor in
                self.customPhotos = updatedMap
                UserDefaults.standard.set(updatedMap, forKey: cacheKey)
            }
        }
    }
    
    /// Returns the user's private cover photo URL for a given mountain ID, if available.
    func photoUrl(for mountainId: String) -> String? {
        return customPhotos[mountainId]
    }
    
    /// Saves a Google Drive photo URL for a specific mountain strictly within the active user's account profile.
    func savePhoto(for mountainId: String, photoUrl: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "UserMountainPhotoService", code: 401, userInfo: [NSLocalizedDescriptionKey: "You must be signed in to save mountain photos to your account."])
        }
        
        // Optimistic update in memory & cache
        customPhotos[mountainId] = photoUrl
        let cacheKey = "user_mountain_photos_\(userId)"
        UserDefaults.standard.set(customPhotos, forKey: cacheKey)
        
        // Save to private user collection in Firestore
        let db = Firestore.firestore()
        let data: [String: Any] = [
            "mountainId": mountainId,
            "photoUrl": photoUrl,
            "updatedAt": Timestamp(date: Date())
        ]
        try await db.collection("users").document(userId).collection("mountainPhotos").document(mountainId).setData(data, merge: true)
    }
}
