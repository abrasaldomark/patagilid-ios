//
//  FullScreenPhotoGalleryView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/29/26.
//

import SwiftUI

/// An immersive, interactive full-screen photo gallery featuring smooth page swiping and pinch/double-tap zoom.
struct FullScreenPhotoGalleryView: View {
    let photoUrls: [String]
    @Binding var selectedIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var currentScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                TabView(selection: $selectedIndex) {
                    ForEach(Array(photoUrls.enumerated()), id: \.offset) { index, urlString in
                        zoomablePhotoView(for: urlString)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .ignoresSafeArea(edges: .bottom)
                .onChange(of: selectedIndex) { _, _ in
                    // Reset zoom smoothly when swiping to a new photo
                    withAnimation(.spring()) {
                        currentScale = 1.0
                        offset = .zero
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Photo \(selectedIndex + 1) of \(photoUrls.count)")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.7), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
    @ViewBuilder
    private func zoomablePhotoView(for urlString: String) -> some View {
        CachedAsyncImage(url: URL(string: urlString)) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(currentScale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                currentScale = max(1.0, min(value, 4.0))
                            }
                            .onEnded { value in
                                if value < 1.0 {
                                    withAnimation(.spring()) {
                                        currentScale = 1.0
                                    }
                                }
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring()) {
                            if currentScale > 1.0 {
                                currentScale = 1.0
                                offset = .zero
                            } else {
                                currentScale = 2.5
                            }
                        }
                    }
            case .failure:
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Unable to render full photo offline")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            @unknown default:
                EmptyView()
            }
        }
    }
}
