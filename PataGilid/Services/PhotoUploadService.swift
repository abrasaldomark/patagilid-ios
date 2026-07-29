//
//  PhotoUploadService.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/28/26.
//

import UIKit
import SwiftUI
import UniformTypeIdentifiers
import FirebaseStorage
import FirebaseAuth
import FirebaseCore

/// Custom Transferable representation that stops SwiftUI from transcoding HEIC photos into JPEG,
/// directly extracting the raw, untouched photo file from the iOS camera library without conversion.
struct UntouchedPhotoFile: Transferable {
    let data: Data
    let fileExtension: String
    let mimeType: String
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .item) { file in
            SentTransferredFile(URL(fileURLWithPath: ""))
        } importing: { received in
            let ext = received.file.pathExtension.lowercased()
            let data = try Data(contentsOf: received.file)
            
            var actualExt = ext
            var mime = "image/jpeg"
            
            if ext == "heic" || ext == "heif" {
                actualExt = "heic"
                mime = "image/heif"
            } else if ext == "png" {
                actualExt = "png"
                mime = "image/png"
            } else if ext == "jpg" || ext == "jpeg" {
                actualExt = "jpg"
                mime = "image/jpeg"
            } else if data.count >= 32 {
                let header = data.prefix(32)
                if let str = String(data: header, encoding: .ascii) ?? String(data: header, encoding: .utf8), str.lowercased().contains("ftyp") {
                    actualExt = "heic"
                    mime = "image/heif"
                }
            }
            if actualExt.isEmpty { actualExt = "heic"; mime = "image/heif" }
            
            print("📦 [UntouchedPhotoFile] Successfully imported raw library file with native extension '.\(actualExt)' (\(data.count / 1024) KB) without transcoding!")
            return UntouchedPhotoFile(data: data, fileExtension: actualExt, mimeType: mime)
        }
    }
}

/// Represents a 100% untouched original camera photo asset directly from iOS Photos.
struct SelectedPhotoAsset {
    let uiImage: UIImage       // For instantaneous UI thumbnail previewing in the app
    let originalData: Data     // 100% untouched original bitstream preserving full camera EXIF, size, and dimensions
    let fileExtension: String  // e.g. "heic", "jpg", "png"
    let mimeType: String       // e.g. "image/heif", "image/jpeg", "image/png"
}

/// Handles uploading untouched climb photos to cloud storage.
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
    
    /// Uploads up to 50 untouched original climb photos directly into the hiker's private "PataGilid Climb Memories" Google Drive folder.
    /// - Parameters:
    ///   - assets: Array of untouched SelectedPhotoAsset items to upload.
    ///   - userId: The ID of the authenticated user.
    /// - Returns: An array of direct viewing URL strings from Google Drive.
    static func uploadPhotos(assets: [SelectedPhotoAsset], userId: String) async throws -> [String] {
        guard !assets.isEmpty else { return [] }
        
        var downloadUrls: [String] = []
        let assetsToUpload = Array(assets.prefix(50)) // Support up to 50 high-resolution climb photos!
        
        for (index, asset) in assetsToUpload.enumerated() {
            let photoName = "climb_\(Int(Date().timeIntervalSince1970))_\(index + 1)"
            do {
                let driveViewUrl = try await GoogleDriveService.shared.uploadPhotoAsset(
                    data: asset.originalData,
                    fileName: photoName,
                    fileExtension: asset.fileExtension,
                    mimeType: asset.mimeType
                )
                downloadUrls.append(driveViewUrl)
                // Instantly cache uploaded photo to local disk so it renders offline without re-downloading
                LocalPhotoCache.shared.save(image: asset.uiImage, for: driveViewUrl)
                print("📸 [PhotoUploadService] Successfully stored untouched original (\(asset.fileExtension.uppercased())) photo #\(index + 1) in Google Drive!")
            } catch {
                print("❌ [PhotoUploadService] Failed to upload photo #\(index + 1) to Google Drive: \(error.localizedDescription)")
                throw error
            }
        }
        
        return downloadUrls
    }
}
