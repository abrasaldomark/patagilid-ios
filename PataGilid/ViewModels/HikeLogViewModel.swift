//
//  HikeLogViewModel.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/28/26.
//

import SwiftUI
import UIKit
import PhotosUI
import Photos
import Combine
import FirebaseAuth
import FirebaseFirestore
import UniformTypeIdentifiers

/// The result of a single climb attempt — mutually exclusive.
enum ClimbOutcome: String, CaseIterable {
    case summited  = "Summited"
    case backedOut = "Backed Out (DNF)"
    
    var icon: String {
        switch self {
        case .summited:  return "mountain.2.fill"
        case .backedOut: return "arrow.uturn.backward.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .summited:  return "orange"
        case .backedOut: return "red"
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
    @Published var routeType: String = "Back Trail"
    @Published var exitTrailName: String = ""
    @Published var trailDifficulty: String = ""
    @Published var trailClass: String = ""
    @Published var waypoints: [String] = []
    
    // MARK: - Photo Attachments
    @Published var selectedPhotos: [PhotosPickerItem] = []
    @Published var selectedPhotoAssets: [SelectedPhotoAsset] = []
    @Published var existingPhotoUrls: [String] = []
    
    var selectedImages: [UIImage] {
        selectedPhotoAssets.map { $0.uiImage }
    }
    
    var totalPhotosCount: Int {
        existingPhotoUrls.count + selectedPhotoAssets.count
    }
    
    // MARK: - Status
    @Published var isSaving: Bool = false
    @Published var errorMessage: String? = nil
    @Published var didCompleteSuccess: Bool = false
    
    // MARK: - Photo Loading & Deletion
    
    /// Loads untouched camera bitstreams asynchronously when the user picks items via PhotosPicker.
    func loadPhotos() async {
        var assets: [SelectedPhotoAsset] = []
        for item in selectedPhotos {
            // 1. DIRECT PHOTOKIT BYPASS: Fetch physical disk asset directly via PHAssetResourceManager!
            // This defeats iOS's default "Most Compatible" transfer policy which transcodes HEIC to JPEG during Transferable import.
            if let untouchedPhotoKitAsset = await fetchUntouchedPhotoKitAsset(from: item) {
                assets.append(untouchedPhotoKitAsset)
            }
            // 2. Try loading raw untouched file representation via Transferable if PhotoKit identifier is unavailable
            else if let untouched = try? await item.loadTransferable(type: UntouchedPhotoFile.self),
               let uiImage = UIImage(data: untouched.data) {
                assets.append(SelectedPhotoAsset(uiImage: uiImage, originalData: untouched.data, fileExtension: untouched.fileExtension, mimeType: untouched.mimeType))
            } 
            // 3. Fallback to standard Data loading
            else if let data = try? await item.loadTransferable(type: Data.self),
                    let uiImage = UIImage(data: data) {
                let format = detectFileFormat(from: data, item: item)
                assets.append(SelectedPhotoAsset(uiImage: uiImage, originalData: data, fileExtension: format.ext, mimeType: format.mime))
            }
        }
        self.selectedPhotoAssets = assets
        
        // When updating / changing photos during log editing, selecting new photos replaces the old ones!
        if !assets.isEmpty && !existingPhotoUrls.isEmpty {
            self.existingPhotoUrls.removeAll()
        }
    }
    
    /// Directly pulls the literal raw file bitstream from device storage via PHAssetResourceManager, completely bypassing iOS automatic JPEG transcoding.
    private func fetchUntouchedPhotoKitAsset(from item: PhotosPickerItem) async -> SelectedPhotoAsset? {
        guard let localId = item.itemIdentifier else { return nil }
        
        // Ensure photo library authorization is granted
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil)
        guard let asset = fetchResult.firstObject else { return nil }
        
        let resources = PHAssetResource.assetResources(for: asset)
        // Prefer the full size photo or main photo resource
        guard let resource = resources.first(where: { $0.type == .photo || $0.type == .fullSizePhoto }) ?? resources.first else { return nil }
        
        let originalName = resource.originalFilename // e.g., "IMG_0745.HEIC"
        let ext = (originalName as NSString).pathExtension.lowercased()
        
        var mime = "image/jpeg"
        var actualExt = ext.isEmpty ? "heic" : ext
        if actualExt == "heic" || actualExt == "heif" {
            mime = "image/heif"
        } else if actualExt == "png" {
            mime = "image/png"
        } else if actualExt == "jpg" || actualExt == "jpeg" {
            mime = "image/jpeg"
        }
        
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true // Easily download original from iCloud if stored there
        
        let rawData: Data? = await withCheckedContinuation { continuation in
            var buffer = Data()
            PHAssetResourceManager.default().requestData(for: resource, options: options, dataReceivedHandler: { data in
                buffer.append(data)
            }, completionHandler: { error in
                if let error = error {
                    print("⚠️ [HikeLogViewModel] Failed to stream PHAssetResource: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: buffer)
                }
            })
        }
        
        guard let data = rawData, !data.isEmpty, let uiImage = UIImage(data: data) else { return nil }
        print("💎 [HikeLogViewModel] Successfully captured untouched raw disk resource: \(originalName) (\(data.count / 1024) KB) as .\(actualExt) with ZERO transcoding!")
        return SelectedPhotoAsset(uiImage: uiImage, originalData: data, fileExtension: actualExt, mimeType: mime)
    }
    
    /// Detects original file format directly from binary file headers (magic bytes) to prevent converting to JPEG.
    private func detectFileFormat(from data: Data, item: PhotosPickerItem) -> (ext: String, mime: String) {
        // 1. Inspect the raw physical binary file header ("magic bytes") directly from the bitstream!
        if data.count >= 12 {
            let bytes = [UInt8](data.prefix(12))
            // JPEG signature (FF D8 FF)
            if bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
                return ("jpg", "image/jpeg")
            }
            // PNG signature (89 50 4E 47)
            if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
                return ("png", "image/png")
            }
            // HEIF / HEIC container (ISOBMFF box format with 'ftyp' header)
            if data.count >= 32 {
                let headerData = data.prefix(32)
                if let str = String(data: headerData, encoding: .ascii) ?? String(data: headerData, encoding: .utf8), str.lowercased().contains("ftyp") {
                    return ("heic", "image/heif")
                }
            }
        }
        
        // 2. Fallback to iOS UniformTypeIdentifiers metadata from PhotosPicker
        for contentType in item.supportedContentTypes {
            let id = contentType.identifier.lowercased()
            if contentType.conforms(to: .heic) || contentType.conforms(to: .heif) || id.contains("heic") || id.contains("heif") {
                return ("heic", "image/heif")
            } else if contentType.conforms(to: .png) || id.contains("png") {
                return ("png", "image/png")
            } else if contentType.conforms(to: .jpeg) || id.contains("jpeg") || id.contains("jpg") {
                return ("jpg", "image/jpeg")
            }
        }
        
        // Default to HEIC for modern iPhone photo libraries
        return ("heic", "image/heif")
    }
    
    /// Removes a photo at a specific index from both thumbnails and picker selection.
    func removeImage(at index: Int) {
        guard index < selectedPhotoAssets.count else { return }
        selectedPhotoAssets.remove(at: index)
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
        self.outcome = log.didSummit ? .summited : .backedOut
        self.trailName = log.trailName
        self.routeType = log.routeType
        self.exitTrailName = log.exitTrailName
        self.trailDifficulty = log.trailDifficulty
        self.trailClass = log.trailClass
        self.existingPhotoUrls = log.cleanPhotoUrls
        self.waypoints = log.waypoints
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
        
        let cleanTrailName = trailName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTrailName.isEmpty else {
            errorMessage = "Please enter the Trail Name."
            return
        }
        
        if routeType == "Traverse" {
            let cleanExitTrail = exitTrailName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanExitTrail.isEmpty else {
                errorMessage = "Please enter the Exit Trail Name."
                return
            }
        }
        
        if routeType == "Circuit" {
            let validWaypoints = waypoints.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            guard !validWaypoints.isEmpty else {
                errorMessage = "Please add at least one Waypoint."
                return
            }
        }
        
        isSaving = true
        errorMessage = nil
        
        Task {
            do {
                // Commit-on-Climb: If this is an uncommitted custom mountain staged in local memory, commit it to Firestore now!
                await MountainsViewModel.shared?.commitStagedMountainIfNeeded(mountain)
                
                var newlyUploadedUrls: [String] = []
                if !selectedPhotoAssets.isEmpty {
                    newlyUploadedUrls = try await PhotoUploadService.uploadPhotos(assets: selectedPhotoAssets, userId: user.uid)
                }
                
                let combinedPhotoUrls = existingPhotoUrls + newlyUploadedUrls
                
                // Clean up removed Google Drive photos when editing an existing climb log
                if let originalLog = editingLog, !originalLog.photoUrls.isEmpty {
                    let removedUrls = originalLog.photoUrls.filter { !existingPhotoUrls.contains($0) }
                    if !removedUrls.isEmpty {
                        print("🗑️ Cleaning up \(removedUrls.count) removed climb photos from Google Drive...")
                        await GoogleDriveService.shared.deletePhotos(atUrls: removedUrls)
                    }
                }
                
                let cleanTrailName = trailName.trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanExitTrail = (routeType == "Traverse" && !exitTrailName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? exitTrailName.trimmingCharacters(in: .whitespacesAndNewlines) : ""
                let cleanDifficulty = trailDifficulty.trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanTrailClass = trailClass.trimmingCharacters(in: .whitespacesAndNewlines)

                var hikeLog = HikeLog(
                    userId: user.uid,
                    mountainId: mountain.id,
                    dateTimeStart: dateTimeStart,
                    dateTimeEnd: dateTimeEnd,
                    didSummit: outcome == .summited,
                    photoUrls: combinedPhotoUrls,
                    trailName: cleanTrailName,
                    routeType: routeType,
                    exitTrailName: cleanExitTrail,
                    trailDifficulty: cleanDifficulty,
                    trailClass: cleanTrailClass,
                    waypoints: routeType == "Circuit" ? waypoints.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } : []
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
    
    /// Permanently removes a recorded climb log from Firestore and cleans up its attached Google Drive photos.
    func deleteLog(_ log: HikeLog, completion: @escaping () -> Void = {}) {
        guard let user = Auth.auth().currentUser, let docId = log.id else { return }
        isSaving = true
        if !log.photoUrls.isEmpty {
            Task {
                print("🗑️ Removing \(log.photoUrls.count) attached photos from Google Drive for deleted log...")
                await GoogleDriveService.shared.deletePhotos(atUrls: log.photoUrls)
            }
        }
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
