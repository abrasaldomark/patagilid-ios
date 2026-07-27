//
//  MountainHeaderImageView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/27/26.
//

import SwiftUI
import FirebaseFirestore

/// A community-driven image view that renders the latest summit photography uploaded by hikers in their log entries.
/// Defaults to a clean, classic mountain icon placeholder when no community photos have been uploaded yet.
struct MountainHeaderImageView: View {
    let mountain: Mountain
    var isThumbnail: Bool = false
    
    @State private var communityPhotoURL: URL? = nil
    @State private var isLoadingCommunityPhoto: Bool = true
    
    var body: some View {
        Group {
            if let photoURL = communityPhotoURL {
                // Live Community Climb Photo
                AsyncImage(url: photoURL) { phase in
                    switch phase {
                    case .empty:
                        defaultPlaceholder
                            .overlay(ProgressView().tint(.white).scaleEffect(isThumbnail ? 0.6 : 1.0))
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .overlay(imageVignette)
                    case .failure:
                        defaultPlaceholder
                    @unknown default:
                        defaultPlaceholder
                    }
                }
            } else {
                // Default clean placeholder until a community climb photo is uploaded
                defaultPlaceholder
            }
        }
        .frame(width: isThumbnail ? 52 : nil, height: isThumbnail ? 52 : 220)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: isThumbnail ? 12 : 16))
        .onAppear {
            if !isThumbnail {
                fetchLatestCommunityPhoto()
            }
        }
    }
    
    /// Clean, minimalist default placeholder when no hiker photo exists yet.
    private var defaultPlaceholder: some View {
        ZStack {
            if isThumbnail {
                Color.secondary.opacity(0.15)
            } else {
                LinearGradient(
                    colors: [.black.opacity(0.85), .teal.opacity(0.5), .black.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            
            Image(systemName: "mountain.2.fill")
                .font(.system(size: isThumbnail ? 22 : 64, weight: .medium))
                .foregroundColor(isThumbnail ? .secondary : .white.opacity(0.35))
        }
    }
    
    /// Subtle gradient vignette overlay to guarantee pristine readability of overlying white text titles.
    private var imageVignette: some View {
        LinearGradient(
            colors: [
                .black.opacity(isThumbnail ? 0.0 : 0.65),
                .black.opacity(isThumbnail ? 0.0 : 0.1),
                .black.opacity(isThumbnail ? 0.15 : 0.8)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    /// Query Firestore for real-time community summit photo uploads.
    private func fetchLatestCommunityPhoto() {
        let db = Firestore.firestore()
        db.collection("hikeLogs")
            .whereField("mountainId", isEqualTo: mountain.id)
            .whereField("photoURLs", isNotEqualTo: [])
            .order(by: "photoURLs")
            .order(by: "climbDate", descending: true)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    self.isLoadingCommunityPhoto = false
                    if let doc = snapshot?.documents.first,
                       let urls = doc.data()["photoURLs"] as? [String],
                       let firstURLString = urls.first,
                       let url = URL(string: firstURLString) {
                        self.communityPhotoURL = url
                    }
                }
            }
    }
}

#Preview {
    VStack(spacing: 20) {
        MountainHeaderImageView(mountain: Mountain(id: "1", name: "Mt. Apo", description: "Highest peak in the Philippines.", elevationMASL: 2954, latitude: 6.98, longitude: 125.27, region: "Region 11", islandGroup: .mindanao, difficultyLevel: "7/9", trailClass: "Class 2-4"), isThumbnail: false)
        
        HStack(spacing: 20) {
            MountainHeaderImageView(mountain: Mountain(id: "2", name: "Mt. Kanlaon", description: "Highest peak in the Visayas.", elevationMASL: 2465, latitude: 10.4, longitude: 123.1, region: "Region 6", islandGroup: .visayas, difficultyLevel: "8/9", trailClass: "Class 3-4"), isThumbnail: true)
            MountainHeaderImageView(mountain: Mountain(id: "3", name: "Mt. Batulao", description: "Popular beginner ridge hike.", elevationMASL: 811, latitude: 14.0, longitude: 120.8, region: "Region 4A", islandGroup: .luzon, difficultyLevel: "4/9", trailClass: "Class 2-3"), isThumbnail: true)
        }
    }
    .padding()
}
