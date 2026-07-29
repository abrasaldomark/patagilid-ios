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
    
    // MARK: - Photo Attachments (Max 50)
    @Published var selectedPhotos: [PhotosPickerItem] = []
    @Published var selectedImages: [UIImage] = []
    @Published var existingPhotoUrls: [String] = []
    
    var totalPhotosCount: Int {
        existingPhotoUrls.count + selectedImages.count
    }
    
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
    
    /// Removes an existing photo URL from an existing log being edited.
    func removeExistingImage(at index: Int) {
        guard index < existingPhotoUrls.count else { return }
        existingPhotoUrls.remove(at: index)
    }
    
    /// Populates form state from an existing log when in edit mode.
    func setupForEditing(log: HikeLog) {
        self.dateTimeStart = log.dateTimeStart
        self.dateTimeEnd = log.dateTimeEnd
        self.outcome = log.didSummit ? .summited : .turnedBack
        self.trailName = log.trailName ?? ""
        self.isTraverse = log.isTraverse == true
        self.exitTrailName = log.exitTrailName ?? ""
        self.trailDifficulty = log.trailDifficulty ?? ""
        self.trailClass = log.trailClass ?? ""
        self.existingPhotoUrls = log.cleanPhotoUrls
    }
    
    // MARK: - Submission & Deletion
    
    /// Validates form, uploads attached photos, triggers Commit-on-Climb if needed, and writes or updates HikeLog in Firestore.
    func submitLog(for mountain: Mountain, editingLog: HikeLog? = nil, onSave: @escaping (HikeLog) -> Void = { _ in }) {
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
                // Commit-on-Climb: If this is an uncommitted custom mountain staged in local memory, commit it to Firestore now!
                await PeaksViewModel.shared?.commitStagedMountainIfNeeded(mountain)
                
                var newlyUploadedUrls: [String] = []
                if !selectedImages.isEmpty {
                    newlyUploadedUrls = try await PhotoUploadService.uploadPhotos(images: selectedImages, userId: user.uid)
                }
                
                let combinedPhotoUrls = existingPhotoUrls + newlyUploadedUrls
                
                let cleanTrailName = trailName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : trailName.trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanExitTrail = (isTraverse && !exitTrailName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? exitTrailName.trimmingCharacters(in: .whitespacesAndNewlines) : nil
                let cleanDifficulty = trailDifficulty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : trailDifficulty.trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanTrailClass = trailClass.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : trailClass.trimmingCharacters(in: .whitespacesAndNewlines)

                var hikeLog = HikeLog(
                    userId: user.uid,
                    mountainId: mountain.id,
                    dateTimeStart: dateTimeStart,
                    dateTimeEnd: dateTimeEnd,
                    didSummit: outcome == .summited,
                    photoUrls: combinedPhotoUrls,
                    trailName: cleanTrailName,
                    isTraverse: isTraverse ? true : nil,
                    exitTrailName: cleanExitTrail,
                    trailDifficulty: cleanDifficulty,
                    trailClass: cleanTrailClass
                )
                
                let db = Firestore.firestore()
                let logsRef = db.collection("users").document(user.uid).collection("hikeLogs")
                
                if let docId = editingLog?.id {
                    hikeLog.id = docId
                    try logsRef.document(docId).setData(from: hikeLog) { [weak self] error in
                        Task { @MainActor [weak self] in
                            self?.isSaving = false
                            if let error {
                                self?.errorMessage = "Failed to update: \(error.localizedDescription)"
                            } else {
                                self?.didCompleteSuccess = true
                                onSave(hikeLog)
                            }
                        }
                    }
                } else {
                    try logsRef.addDocument(from: hikeLog) { [weak self] error in
                        Task { @MainActor [weak self] in
                            self?.isSaving = false
                            if let error {
                                self?.errorMessage = "Failed to save: \(error.localizedDescription)"
                            } else {
                                self?.didCompleteSuccess = true
                                onSave(hikeLog)
                            }
                        }
                    }
                }
            } catch {
                self.isSaving = false
                self.errorMessage = "Photo upload failed: \(error.localizedDescription)"
            }
        }
    }
    
    /// Permanently removes a recorded climb log from Firestore.
    func deleteLog(_ log: HikeLog, completion: @escaping () -> Void = {}) {
        guard let user = Auth.auth().currentUser, let docId = log.id else { return }
        isSaving = true
        Firestore.firestore().collection("users").document(user.uid).collection("hikeLogs").document(docId).delete { [weak self] error in
            Task { @MainActor [weak self] in
                self?.isSaving = false
                if let error {
                    self?.errorMessage = "Failed to delete log: \(error.localizedDescription)"
                } else {
                    completion()
                }
            }
        }
    }
}
