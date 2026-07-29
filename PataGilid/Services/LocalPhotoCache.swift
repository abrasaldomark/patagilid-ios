//
//  LocalPhotoCache.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/29/26.
//

import UIKit
import Foundation

/// A persistent, offline-first image caching service utilizing both high-speed memory (RAM) and local disk storage.
/// Ensures all climb photos and mountain imagery load instantaneously offline without re-requesting from network servers.
final class LocalPhotoCache {
    static let shared = LocalPhotoCache()
    
    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private var diskCacheDirectory: URL?
    private let ioQueue = DispatchQueue(label: "com.patagilid.localPhotoCacheQueue", qos: .background)
    
    private init() {
        memoryCache.countLimit = 150 // Keep up to 150 images in high-speed RAM
        memoryCache.totalCostLimit = 1024 * 1024 * 100 // Up to 100MB RAM limit
        
        setupDiskCache()
    }
    
    private func setupDiskCache() {
        if let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let photoDir = cacheDir.appendingPathComponent("PataGilidOfflinePhotos", isDirectory: true)
            do {
                if !fileManager.fileExists(atPath: photoDir.path) {
                    try fileManager.createDirectory(at: photoDir, withIntermediateDirectories: true, attributes: nil)
                }
                self.diskCacheDirectory = photoDir
            } catch {
                print("❌ [LocalPhotoCache] Failed to create offline photo directory: \(error)")
            }
        }
    }
    
    /// Converts any URL string or Google Drive identifier into a deterministic, safe filesystem filename.
    private func filename(for key: String) -> String {
        guard let data = key.data(using: .utf8) else { return "\(key.hashValue).jpg" }
        let base64 = data.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        // Prefix length to prevent path length overflow on iOS file system while maintaining uniqueness
        return "\(base64.prefix(100))_\(abs(key.hashValue)).jpg"
    }
    
    /// Synchronously retrieves a cached image from high-speed RAM or persistent disk storage if available.
    func image(for key: String) -> UIImage? {
        guard !key.isEmpty else { return nil }
        
        // 1. Check ultra-fast in-memory cache first
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }
        
        // 2. Check permanent local offline disk cache
        guard let directory = diskCacheDirectory else { return nil }
        let fileURL = directory.appendingPathComponent(filename(for: key))
        
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let diskImage = UIImage(data: data) else {
            return nil
        }
        
        // Populate RAM cache for future zero-latency accesses in this session
        memoryCache.setObject(diskImage, forKey: key as NSString)
        return diskImage
    }
    
    /// Saves a UIImage into both RAM and persistent offline disk storage immediately.
    func save(image: UIImage, for key: String) {
        guard !key.isEmpty else { return }
        
        // Store in memory
        memoryCache.setObject(image, forKey: key as NSString)
        
        // Asynchronously persist to local disk
        guard let directory = diskCacheDirectory else { return }
        let fileURL = directory.appendingPathComponent(filename(for: key))
        
        ioQueue.async {
            if let jpegData = image.jpegData(compressionQuality: 0.85) {
                do {
                    try jpegData.write(to: fileURL, options: .atomic)
                    print("💾 [LocalPhotoCache] Successfully saved offline copy to disk for: \(key.prefix(45))...")
                } catch {
                    print("❌ [LocalPhotoCache] Failed saving photo to disk: \(error)")
                }
            }
        }
    }
    
    /// Clears all offline photo disk storage if desired by the user.
    func clearCache() {
        memoryCache.removeAllObjects()
        guard let directory = diskCacheDirectory else { return }
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            try? self.fileManager.removeItem(at: directory)
            self.setupDiskCache()
            print("🧹 [LocalPhotoCache] All offline cached photos cleared.")
        }
    }
}
