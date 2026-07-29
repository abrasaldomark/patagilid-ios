//
//  SummitLogsViewModel.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/28/26.
//

import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

/// ViewModel providing a real-time feed of the signed-in hiker's personal summit logs
/// from `users/{userId}/hikeLogs`, ordered by most recent attempt first.
@MainActor
class SummitLogsViewModel: ObservableObject {
    @Published var logs: [HikeLog] = []
    @Published var isLoading: Bool = true
    @Published var errorMessage: String? = nil
    
    /// O(1) mountain lookup map built from the bundled JSON catalog.
    private(set) var mountainMap: [String: Mountain] = [:]
    private var listener: ListenerRegistration?
    
    init() {
        buildMountainMap()
        subscribe()
    }
    
    deinit {
        listener?.remove()
    }
    
    // MARK: - Mountain Lookup
    
    func mountain(for id: String) -> Mountain? {
        mountainMap[id]
    }
    
    private func buildMountainMap() {
        let all = MountainDataSeeder.shared.officialMountains
        mountainMap = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    }
    
    // MARK: - Firestore Listener
    
    func subscribe() {
        guard let user = Auth.auth().currentUser else {
            isLoading = false
            errorMessage = "Sign in to view your summit logs."
            return
        }
        
        isLoading = true
        errorMessage = nil
        listener?.remove()
        
        listener = Firestore.firestore()
            .collection("users")
            .document(user.uid)
            .collection("hikeLogs")
            .order(by: "dateTimeStart", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                isLoading = false
                if let error {
                    errorMessage = error.localizedDescription
                    // Offline fallback: restore directly from hiker's private Google Drive backup!
                    Task {
                        if let restored = try? await GoogleDriveService.shared.loadSummitLogs(), !restored.isEmpty {
                            await MainActor.run {
                                self.logs = restored
                                self.errorMessage = nil
                            }
                        }
                    }
                    return
                }
                let fetchedLogs: [HikeLog] = snapshot?.documents.compactMap {
                    try? $0.data(as: HikeLog.self)
                } ?? []
                logs = fetchedLogs
                
                // Simultaneously sync & preserve hiker's personal climbing legacy to their Google Drive!
                if !fetchedLogs.isEmpty {
                    Task {
                        try? await GoogleDriveService.shared.saveSummitLogs(fetchedLogs)
                    }
                }
            }
    }
    
    // MARK: - Deletion
    
    func delete(_ log: HikeLog) {
        guard let user = Auth.auth().currentUser, let logId = log.id else { return }
        Firestore.firestore()
            .collection("users").document(user.uid)
            .collection("hikeLogs").document(logId)
            .delete()
    }
}
