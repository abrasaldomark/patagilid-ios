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
    
    /// Uploads up to 3 images for a specific user and returns their storage download URLs.
    /// - Parameters:
    ///   - images: Array of UIImages to upload.
    ///   - userId: The ID of the authenticated user.
    /// - Returns: An array of download URL strings from Firebase Storage.
    static func uploadPhotos(images: [UIImage], userId: String) async throws -> [String] {
        guard !images.isEmpty else { return [] }
        
        var downloadUrls: [String] = []
        let imagesToUpload = Array(images.prefix(3))
        
        for (index, image) in imagesToUpload.enumerated() {
            // Compress image to JPEG at 70% quality for optimal bandwidth usage and storage efficiency
            guard let imageData = image.jpegData(compressionQuality: 0.7) else {
                continue
            }
            
            let imageId = UUID().uuidString
            let filePath = "users/\(userId)/hikeLogs/\(imageId).jpg"
            let candidateRefs = candidateReferences(for: filePath)
            
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            var successfulDownloadUrl: String? = nil
            var lastError: Error? = nil
            
            // Attempt upload across candidate bucket domain names (.firebasestorage.app vs .appspot.com)
            for fileRef in candidateRefs {
                do {
                    _ = try await fileRef.putDataAsync(imageData, metadata: metadata)
                    let downloadURL = try await fileRef.downloadURL()
                    successfulDownloadUrl = downloadURL.absoluteString
                    break
                } catch {
                    lastError = error
                    print("⚠️ [PhotoUploadService] Upload failed for candidate bucket (\(fileRef.bucket)): \(error)")
                    
                    // If Google Cloud returns 404 Not Found, try the fallback domain in the next loop iteration
                    if case .objectNotFound = error as? StorageError {
                        continue
                    }
                    // If it's permission denied or other error, fail immediately without retrying domains
                    break
                }
            }
            
            if let url = successfulDownloadUrl {
                downloadUrls.append(url)
            } else if let error = lastError {
                print("❌ [PhotoUploadService] All upload attempts failed for photo #\(index+1): \(error)")
                if case .objectNotFound = error as? StorageError {
                    throw NSError(domain: "PhotoUploadService", code: 404, userInfo: [
                        NSLocalizedDescriptionKey: "Cloud Storage bucket not found (HTTP 404). Please ensure you clicked 'Get Started' under Storage in Firebase Console."
                    ])
                }
                throw error
            }
        }
        
        return downloadUrls
    }
}
