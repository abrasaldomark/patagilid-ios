//
//  HikeLogViewModel.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/28/26.
//

import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

/// The result of a single climb attempt — mutually exclusive.
enum ClimbOutcome: String, CaseIterable {
    case summited    = "Summited"
    case turnedBack  = "Turned Back (DNF)"
    
    var icon: String {
        switch self {
        case .summited:   return "mountain.2.fill"
        case .turnedBack: return "arrow.uturn.backward.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .summited:   return "orange"
        case .turnedBack: return "red"
        }
    }
}

/// ViewModel managing hike log form state and Firestore persistence.
@MainActor
class HikeLogViewModel: ObservableObject {
    
    // MARK: - Form Fields
    @Published var dateTime: Date = Date()
    @Published var outcome: ClimbOutcome = .summited
    
    // MARK: - Status
    @Published var isSaving: Bool = false
    @Published var errorMessage: String? = nil
    @Published var didCompleteSuccess: Bool = false
    
    // MARK: - Submission
    
    /// Validates the form and writes the HikeLog to `users/{userId}/hikeLogs/` in Firestore.
    func submitLog(for mountainId: String) {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "You must be signed in to record climb logs."
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        let hikeLog = HikeLog(
            userId: user.uid,
            mountainId: mountainId,
            dateTime: dateTime,
            didSummit: outcome == .summited,
            photoUrls: []
        )
        
        let db = Firestore.firestore()
        let ref = db.collection("users").document(user.uid).collection("hikeLogs")
        
        do {
            try ref.addDocument(from: hikeLog) { [weak self] error in
                Task { @MainActor [weak self] in
                    self?.isSaving = false
                    if let error {
                        self?.errorMessage = "Failed to save: \(error.localizedDescription)"
                    } else {
                        self?.didCompleteSuccess = true
                    }
                }
            }
        } catch {
            isSaving = false
            errorMessage = "Encoding error: \(error.localizedDescription)"
        }
    }
}
