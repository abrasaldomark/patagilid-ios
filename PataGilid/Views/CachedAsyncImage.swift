//
//  CachedAsyncImage.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/29/26.
//

import SwiftUI
import UIKit

/// A robust, drop-in replacement for SwiftUI's `AsyncImage` that integrates seamlessly with `LocalPhotoCache`.
/// Reads from local offline memory and disk storage first before performing any network requests.
struct CachedAsyncImage<Content: View>: View {
    private let url: URL?
    private let scale: CGFloat
    private let transaction: Transaction
    private let content: (AsyncImagePhase) -> Content
    
    @State private var phase: AsyncImagePhase = .empty
    
    init(url: URL?,
         scale: CGFloat = 1.0,
         transaction: Transaction = Transaction(),
         @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        self.scale = scale
        self.transaction = transaction
        self.content = content
    }
    
    var body: some View {
        content(phase)
            .onAppear {
                loadImage()
            }
            .onChange(of: url) { _, _ in
                loadImage()
            }
    }
    
    private func loadImage() {
        guard let url = url, let urlString = url.absoluteString as String?, !urlString.isEmpty else {
            phase = .empty
            return
        }
        
        // 1. Instantaneous offline lookup from LocalPhotoCache (RAM / Persistent Disk)
        if let cachedImage = LocalPhotoCache.shared.image(for: urlString) {
            withAnimation(transaction.animation) {
                phase = .success(Image(uiImage: cachedImage))
            }
            return
        }
        
        // 2. Fetch over network if not cached yet
        phase = .empty
        
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let httpResponse = response as? HTTPURLResponse,
                   (200...299).contains(httpResponse.statusCode),
                   let uiImage = UIImage(data: data) {
                    
                    // Persist newly fetched image to LocalPhotoCache forever
                    LocalPhotoCache.shared.save(image: uiImage, for: urlString)
                    
                    await MainActor.run {
                        withAnimation(transaction.animation) {
                            phase = .success(Image(uiImage: uiImage))
                        }
                    }
                } else {
                    await MainActor.run {
                        phase = .failure(NSError(domain: "CachedAsyncImage", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: nil))
                    }
                }
            } catch {
                await MainActor.run {
                    phase = .failure(error)
                }
            }
        }
    }
}
