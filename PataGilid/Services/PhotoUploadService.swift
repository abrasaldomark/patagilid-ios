//
//  PhotoUploadService.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/28/26.
//

import UIKit
import FirebaseStorage
import FirebaseAuth
import FirebaseCore

/// Handles compressing and uploading climb photos to Firebase Cloud Storage.
struct PhotoUploadService {
    
    /// Returns candidate Storage references, automatically falling back between `.firebasestorage.app` and `.appspot.com`
    /// to handle domain alias discrepancies between Google Cloud provisioning and GoogleService-Info.plist.
    private static func candidateReferences(for filePath: String) -> [StorageReference] {
        var refs: [StorageReference] = [Storage.storage().reference().child(filePath)]
        
        if let defaultBucket = FirebaseApp.app()?.options.storageBucket {
            if defaultBucket.contains(".firebasestorage.app") {
                let appspotBucket = defaultBucket.replacingOccurrences(of: ".firebasestorage.app", with: ".appspot.com")
                refs.append(Storage.storage(url: "gs://\(appspotBucket)").reference().child(filePath))
            } else if defaultBucket.contains(".appspot.com") {
                let fbBucket = defaultBucket.replacingOccurrences(of: ".appspot.com", with: ".firebasestorage.app")
                refs.append(Storage.storage(url: "gs://\(fbBucket)").reference().child(filePath))
            }
        }
        return refs
    }
    
    /// Uploads up to 3 climb images directly into the hiker's private "PataGilid Climb Memories" Google Drive folder.
    /// - Parameters:
    ///   - images: Array of UIImages to upload.
    ///   - userId: The ID of the authenticated user.
    /// - Returns: An array of direct viewing URL strings from Google Drive.
    static func uploadPhotos(images: [UIImage], userId: String) async throws -> [String] {
        guard !images.isEmpty else { return [] }
        
        var downloadUrls: [String] = []
        let imagesToUpload = Array(images.prefix(3))
        
        for (index, image) in imagesToUpload.enumerated() {
            let photoName = "climb_\(Int(Date().timeIntervalSince1970))_\(index + 1)"
            do {
                let driveViewUrl = try await GoogleDriveService.shared.uploadPhoto(image: image, fileName: photoName)
                downloadUrls.append(driveViewUrl)
                // Instantly cache uploaded photo to local disk so it renders instantly offline without re-downloading
                LocalPhotoCache.shared.save(image: image, for: driveViewUrl)
                print("📸 [PhotoUploadService] Successfully stored photo #\(index + 1) in user's personal Google Drive and cached locally!")
            } catch {
                print("❌ [PhotoUploadService] Failed to upload photo #\(index + 1) to Google Drive: \(error.localizedDescription)")
                throw error
            }
        }
        
        return downloadUrls
    }
}
