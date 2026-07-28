//
//  HikeLogViewModel.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/28/26.
//

import SwiftUI
import UIKit
import PhotosUI
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

/// ViewModel managing hike log form state, photo attachments, and Firestore persistence.
@MainActor
class HikeLogViewModel: ObservableObject {
    
    // MARK: - Form Fields
    @Published var dateTimeStart: Date = Date()
    @Published var dateTimeEnd: Date = Calendar.current.date(byAdding: .hour, value: 8, to: Date()) ?? Date()
    @Published var outcome: ClimbOutcome = .summited
    @Published var trailName: String = ""
    @Published var isTraverse: Bool = false
    @Published var exitTrailName: String = ""
    @Published var trailDifficulty: String = ""
    @Published var trailClass: String = ""
    
    // MARK: - Photo Attachments (Max 3)
    @Published var selectedPhotos: [PhotosPickerItem] = []
    @Published var selectedImages: [UIImage] = []
    
    // MARK: - Status
    @Published var isSaving: Bool = false
    @Published var errorMessage: String? = nil
    @Published var didCompleteSuccess: Bool = false
    
    // MARK: - Photo Loading & Deletion
    
    /// Loads UIImages asynchronously when the user picks items via PhotosPicker.
    func loadPhotos() async {
        var images: [UIImage] = []
        for item in selectedPhotos {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                images.append(uiImage)
            }
        }
        self.selectedImages = images
    }
    
    /// Removes a photo at a specific index from both thumbnails and picker selection.
    func removeImage(at index: Int) {
        guard index < selectedImages.count else { return }
        selectedImages.remove(at: index)
        if index < selectedPhotos.count {
            selectedPhotos.remove(at: index)
        }
    }
    
    // MARK: - Submission
    
    /// Validates form, uploads attached photos to Firebase Storage, and writes HikeLog to Firestore.
    func submitLog(for mountainId: String) {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "You must be signed in to record climb logs."
            return
        }
        
        guard dateTimeEnd > dateTimeStart else {
            errorMessage = "End time must be after start time."
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        Task {
            do {
                var uploadedUrls: [String] = []
                if !selectedImages.isEmpty {
                    uploadedUrls = try await PhotoUploadService.uploadPhotos(images: selectedImages, userId: user.uid)
                }
                
                let cleanTrailName = trailName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : trailName.trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanExitTrail = (isTraverse && !exitTrailName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? exitTrailName.trimmingCharacters(in: .whitespacesAndNewlines) : nil
                let cleanDifficulty = trailDifficulty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : trailDifficulty.trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanTrailClass = trailClass.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : trailClass.trimmingCharacters(in: .whitespacesAndNewlines)

                let hikeLog = HikeLog(
                    userId: user.uid,
                    mountainId: mountainId,
                    dateTimeStart: dateTimeStart,
                    dateTimeEnd: dateTimeEnd,
                    didSummit: outcome == .summited,
                    photoUrls: uploadedUrls,
                    trailName: cleanTrailName,
                    isTraverse: isTraverse,
                    exitTrailName: cleanExitTrail,
                    trailDifficulty: cleanDifficulty,
                    trailClass: cleanTrailClass
                )
                
                let db = Firestore.firestore()
                let ref = db.collection("users").document(user.uid).collection("hikeLogs")
                
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
                self.isSaving = false
                self.errorMessage = "Photo upload failed: \(error.localizedDescription)"
            }
        }
    }
}
