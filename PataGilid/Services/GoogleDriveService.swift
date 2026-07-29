//
//  GoogleDriveService.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/29/26.
//

import UIKit
import GoogleSignIn

/// A pure Swift service leveraging native URLSession to synchronize summit logs and high-resolution climb photos
/// directly into the user's private Google Drive storage via the Google Drive V3 REST API.
class GoogleDriveService {
    static let shared = GoogleDriveService()
    
    private let driveApiBaseUrl = "https://www.googleapis.com/drive/v3/files"
    private let driveUploadUrl = "https://www.googleapis.com/upload/drive/v3/files"
    
    private init() {}
    
    // MARK: - OAuth Token Retrieval
    
    /// Retrieves a valid OAuth access token from active Google Sign-In session, restoring previous sign-in if needed.
    private func fetchAccessToken() async throws -> String {
        var gidUser = GIDSignIn.sharedInstance.currentUser
        if gidUser == nil {
            print("🔄 [GoogleDriveService] Google SignIn currentUser is nil in memory. Attempting to restore previous sign-in from keychain...")
            gidUser = try? await withCheckedThrowingContinuation { continuation in
                GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: user)
                    }
                }
            }
        }
        
        guard let validUser = gidUser else {
            throw NSError(domain: "GoogleDriveService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Your Google session has expired or Drive access was not authorized. Please sign out in the Profile tab and sign back in to enable Drive synchronization."])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            validUser.refreshTokensIfNeeded { user, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let token = user?.accessToken.tokenString {
                    continuation.resume(returning: token)
                } else {
                    continuation.resume(throwing: NSError(domain: "GoogleDriveService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to retrieve Google OAuth access token."]))
                }
            }
        }
    }
    
    // MARK: - Folder & Album Management
    
    /// Finds or creates a designated "PataGilid Climb Memories" photo folder in the root of the user's Google Drive.
    func getOrCreatePhotoFolder() async throws -> String {
        let token = try await fetchAccessToken()
        let folderName = "PataGilid Climb Memories"
        
        // 1. Search for existing folder
        var components = URLComponents(string: driveApiBaseUrl)!
        components.queryItems = [
            URLQueryItem(name: "q", value: "name='\(folderName)' and mimeType='application/vnd.google-apps.folder' and trashed=false"),
            URLQueryItem(name: "fields", value: "files(id, name)")
        ]
        
        var searchRequest = URLRequest(url: components.url!)
        searchRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, searchResponse) = try await URLSession.shared.data(for: searchRequest)
        if let httpResponse = searchResponse as? HTTPURLResponse, httpResponse.statusCode == 200,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let files = json["files"] as? [[String: Any]],
           let firstFile = files.first,
           let existingId = firstFile["id"] as? String {
            print("📁 [GoogleDriveService] Found existing PataGilid photo folder ID: \(existingId)")
            return existingId
        }
        
        // 2. Create new photo folder if not found
        var createRequest = URLRequest(url: URL(string: driveApiBaseUrl)!)
        createRequest.httpMethod = "POST"
        createRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        createRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let metadata: [String: Any] = [
            "name": folderName,
            "mimeType": "application/vnd.google-apps.folder"
        ]
        createRequest.httpBody = try JSONSerialization.data(withJSONObject: metadata)
        
        let (createData, createResponse) = try await URLSession.shared.data(for: createRequest)
        if let httpResponse = createResponse as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            let errorJson = try? JSONSerialization.jsonObject(with: createData) as? [String: Any]
            let googleMessage = (errorJson?["error"] as? [String: Any])?["message"] as? String ?? String(data: createData, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            print("❌ [GoogleDriveService] Folder creation failed: \(googleMessage)")
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw NSError(domain: "GoogleDriveService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Google Drive access denied (\(httpResponse.statusCode)). Please sign out and sign back in with Google to grant Drive permissions, or enable Google Drive API in your Firebase GCP console."])
            }
            throw NSError(domain: "GoogleDriveService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Google Drive folder creation failed: \(googleMessage)"])
        }
        guard let createJson = try? JSONSerialization.jsonObject(with: createData) as? [String: Any],
              let newId = createJson["id"] as? String else {
            throw NSError(domain: "GoogleDriveService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to parse Google Drive album creation response."])
        }
        
        print("🎉 [GoogleDriveService] Created new Google Drive album folder ID: \(newId)")
        return newId
    }
    
    // MARK: - High-Resolution Photo Upload
    
    /// Uploads an uncompressed or high-res summit photo to the user's "PataGilid Climb Memories" Google Drive folder.
    /// Returns a direct viewer URL or File reference string.
    func uploadPhoto(image: UIImage, fileName: String) async throws -> String {
        let token = try await fetchAccessToken()
        let folderId = try await getOrCreatePhotoFolder()
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "GoogleDriveService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare image for upload."])
        }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var components = URLComponents(string: driveUploadUrl)!
        components.queryItems = [
            URLQueryItem(name: "uploadType", value: "multipart"),
            URLQueryItem(name: "fields", value: "id, name, webViewLink")
        ]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let metadata: [String: Any] = [
            "name": "\(fileName).jpg",
            "parents": [folderId]
        ]
        let metadataData = try JSONSerialization.data(withJSONObject: metadata)
        
        var body = Data()
        // Part 1: JSON Metadata
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/json; charset=UTF-8\r\n\r\n".data(using: .utf8)!)
        body.append(metadataData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Part 2: JPEG Media Data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            let errorJson = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any]
            let googleMessage = (errorJson?["error"] as? [String: Any])?["message"] as? String ?? String(data: responseData, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            print("❌ [GoogleDriveService] Photo upload failed: \(googleMessage)")
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw NSError(domain: "GoogleDriveService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Google Drive upload permission denied (\(httpResponse.statusCode)). Please sign out and sign back in to authorize Google Drive access."])
            }
            throw NSError(domain: "GoogleDriveService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Photo upload failed: \(googleMessage)"])
        }
        guard let resultJson = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let fileId = resultJson["id"] as? String else {
            throw NSError(domain: "GoogleDriveService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to process uploaded photo response from Google Drive."])
        }
        
        print("✅ [GoogleDriveService] Successfully stored climb photo in user's Google Drive. File ID: \(fileId)")
        
        // Make image file accessible via direct link so SwiftUI AsyncImage can decode it without login prompts
        if let permUrl = URL(string: "https://www.googleapis.com/drive/v3/files/\(fileId)/permissions") {
            var permReq = URLRequest(url: permUrl)
            permReq.httpMethod = "POST"
            permReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            permReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let permBody = ["role": "reader", "type": "anyone"]
            permReq.httpBody = try? JSONSerialization.data(withJSONObject: permBody)
            _ = try? await URLSession.shared.data(for: permReq)
        }
        
        // Return direct Google Drive download/view URL for AsyncImage
        let directImageUrl = "https://drive.google.com/uc?id=\(fileId)&export=view"
        return directImageUrl
    }
    
    // MARK: - Personal Summit Logs Sync (AppData Folder)
    
    /// Synchronizes the hiker's full chronological climbing logs into Google Drive's hidden private appDataFolder.
    func saveSummitLogs(_ logs: [HikeLog]) async throws {
        let token = try await fetchAccessToken()
        let jsonData = try JSONEncoder().encode(logs)
        let logFileName = "my_summit_logs.json"
        
        // Check if log database file already exists in appDataFolder
        let existingId = try await findAppDataFileId(fileName: logFileName, token: token)
        
        if let fileId = existingId {
            // Update existing file via media PATCH
            let patchUrl = URL(string: "\(driveUploadUrl)/\(fileId)?uploadType=media")!
            var patchRequest = URLRequest(url: patchUrl)
            patchRequest.httpMethod = "PATCH"
            patchRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            patchRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            patchRequest.httpBody = jsonData
            
            let (_, patchResponse) = try await URLSession.shared.data(for: patchRequest)
            guard let httpResponse = patchResponse as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                throw NSError(domain: "GoogleDriveService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to update summit log backup in Google Drive."])
            }
            print("🔄 [GoogleDriveService] Successfully synced & updated \(logs.count) climb logs in Google Drive App Data.")
        } else {
            // Create new log database file via multipart POST in appDataFolder
            let boundary = "Boundary-\(UUID().uuidString)"
            var components = URLComponents(string: driveUploadUrl)!
            components.queryItems = [URLQueryItem(name: "uploadType", value: "multipart")]
            
            var createRequest = URLRequest(url: components.url!)
            createRequest.httpMethod = "POST"
            createRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            createRequest.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            let metadata: [String: Any] = [
                "name": logFileName,
                "parents": ["appDataFolder"]
            ]
            let metadataData = try JSONSerialization.data(withJSONObject: metadata)
            
            var body = Data()
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/json; charset=UTF-8\r\n\r\n".data(using: .utf8)!)
            body.append(metadataData)
            body.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/json\r\n\r\n".data(using: .utf8)!)
            body.append(jsonData)
            body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
            
            createRequest.httpBody = body
            
            let (_, response) = try await URLSession.shared.data(for: createRequest)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                throw NSError(domain: "GoogleDriveService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize summit log database in Google Drive App Data."])
            }
            print("✨ [GoogleDriveService] Created & synced initial climb database in Google Drive App Data.")
        }
    }
    
    /// Loads and decodes the user's saved summit logs from Google Drive's private appDataFolder.
    func loadSummitLogs() async throws -> [HikeLog] {
        let token = try await fetchAccessToken()
        let logFileName = "my_summit_logs.json"
        
        guard let fileId = try await findAppDataFileId(fileName: logFileName, token: token) else {
            print("📭 [GoogleDriveService] No previous summit log database found in Google Drive.")
            return []
        }
        
        let mediaUrl = URL(string: "\(driveApiBaseUrl)/\(fileId)?alt=media")!
        var downloadRequest = URLRequest(url: mediaUrl)
        downloadRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: downloadRequest)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "GoogleDriveService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to download climb history from Google Drive."])
        }
        
        let logs = try JSONDecoder().decode([HikeLog].self, from: data)
        print("🏔️ [GoogleDriveService] Successfully restored \(logs.count) climb logs from Google Drive.")
        return logs
    }
    
    // MARK: - Private Helpers
    
    private func findAppDataFileId(fileName: String, token: String) async throws -> String? {
        var components = URLComponents(string: driveApiBaseUrl)!
        components.queryItems = [
            URLQueryItem(name: "spaces", value: "appDataFolder"),
            URLQueryItem(name: "q", value: "name='\(fileName)' and trashed=false"),
            URLQueryItem(name: "fields", value: "files(id, name)")
        ]
        
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let files = json["files"] as? [[String: Any]],
           let firstFile = files.first,
           let existingId = firstFile["id"] as? String {
            return existingId
        }
        return nil
    }
}
