//
//  HikeLogCreationView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/28/26.
//

import SwiftUI
import PhotosUI

/// Modal sheet for recording a climb attempt — date, summit count, DNF count, and up to 3 photos.
struct HikeLogCreationView: View {
    let mountain: Mountain
    @StateObject private var viewModel = HikeLogViewModel()
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("isPataGilidPro") private var isProUser: Bool = false
    @State private var showProPaywall: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    summitBanner
                    activityForm
                    
                    if isProUser {
                        photosForm
                    } else {
                        lockedProPhotosCard
                    }
                    
                    if let error = viewModel.errorMessage {
                        errorBanner(error)
                            .padding(.bottom, 12)
                    }
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("Log Ascent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .disabled(viewModel.isSaving)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.submitLog(for: mountain.id)
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                                .tint(.emeraldGreen)
                        } else {
                            Text("Save")
                                .fontWeight(.bold)
                                .foregroundColor(.emeraldGreen)
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .onChange(of: viewModel.didCompleteSuccess) { _, success in
                if success { dismiss() }
            }
            .sheet(isPresented: $showProPaywall) {
                ProPaywallView()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var summitBanner: some View {
        HStack(spacing: 16) {
            Image(systemName: "mountain.2.fill")
                .font(.system(size: 28))
                .foregroundColor(.emeraldGreen)
                .frame(width: 56, height: 56)
                .background(Color.emeraldGreen.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("TARGET SUMMIT")
                    .font(.caption2)
                    .fontWeight(.black)
                    .foregroundColor(.gray)
                    .tracking(1.5)
                
                Text(mountain.name)
                    .font(.title3)
                    .fontWeight(.black)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text("\(mountain.elevationMASL) MASL")
                    .font(.caption)
                    .fontWeight(.heavy)
                    .foregroundColor(.teal)
                
                Text(mountain.region)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding()
        .background(Color.secondary.opacity(0.07))
        .cornerRadius(16)
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var activityForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity Parameters")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                // Date & Time Start
                DatePicker(
                    "Start",
                    selection: $viewModel.dateTimeStart,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .padding()
                
                Divider().padding(.leading)
                
                // Date & Time End
                DatePicker(
                    "End",
                    selection: $viewModel.dateTimeEnd,
                    in: viewModel.dateTimeStart...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .padding()
                
                Divider().padding(.leading)
                
                // Outcome selector — mutually exclusive
                VStack(alignment: .leading, spacing: 10) {
                    Text("Climb Outcome")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        outcomeCard(.summited)
                        outcomeCard(.turnedBack)
                    }
                }
                .padding()
            }
            .background(Color.secondary.opacity(0.06))
            .cornerRadius(14)
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private func outcomeCard(_ option: ClimbOutcome) -> some View {
        let isSelected = viewModel.outcome == option
        let accentColor: Color = option == .summited ? .orange : .red
        
        Button {
            viewModel.outcome = option
        } label: {
            VStack(spacing: 8) {
                Image(systemName: option.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? accentColor : .gray)
                Text(option.rawValue)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? accentColor : .gray)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: viewModel.outcome)
    }
    
    // MARK: - Photos Attachment Form
    
    private var lockedProPhotosCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "camera.fill.badge.ellipsis")
                    .font(.system(size: 26))
                    .foregroundColor(.orange)
                    .frame(width: 48, height: 48)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Climb Photo Memories")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text("PRO")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .clipShape(Capsule())
                    }
                    Text("Attach up to 3 summit & jump-off photos to your climb records.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            
            Button {
                showProPaywall = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                    Text("Unlock PataGilid Pro — ₱249")
                        .fontWeight(.bold)
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.orange, .red.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: Color.orange.opacity(0.3), radius: 6, x: 0, y: 3)
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.35), lineWidth: 1.5)
        )
        .padding(.horizontal)
    }
    
    private var photosForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Climb Photos")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.selectedImages.count)/3 Max")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(viewModel.selectedImages.count == 3 ? .orange : .secondary)
            }
            .padding(.horizontal)
            
            VStack(spacing: 16) {
                if !viewModel.selectedImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(viewModel.selectedImages.enumerated()), id: \.offset) { index, uiImage in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                                    
                                    Button {
                                        withAnimation {
                                            viewModel.removeImage(at: index)
                                        }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(.white)
                                            .background(Circle().fill(Color.black.opacity(0.6)).frame(width: 20, height: 20))
                                    }
                                    .padding(6)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                
                if viewModel.selectedImages.count < 3 {
                    PhotosPicker(
                        selection: $viewModel.selectedPhotos,
                        maxSelectionCount: 3,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        HStack(spacing: 10) {
                            Image(systemName: "photo.badge.plus")
                                .font(.title3)
                            Text(viewModel.selectedImages.isEmpty ? "Add Photos (Max 3)" : "Change / Add Photos")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.emeraldGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.emeraldGreen.opacity(0.12))
                        .cornerRadius(12)
                        .padding(.horizontal, viewModel.selectedImages.isEmpty ? 0 : 8)
                    }
                    .onChange(of: viewModel.selectedPhotos) { _, _ in
                        Task {
                            await viewModel.loadPhotos()
                        }
                    }
                }
            }
            .padding(14)
            .background(Color.secondary.opacity(0.06))
            .cornerRadius(14)
            .padding(.horizontal)
        }
    }
    
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.subheadline)
            Spacer()
        }
        .padding()
        .background(Color.red.opacity(0.12))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

#Preview {
    HikeLogCreationView(mountain: Mountain(
        id: "preview",
        name: "Mt. Pulag",
        description: "Sea of Clouds",
        elevationMASL: 2928,
        latitude: 16.59,
        longitude: 120.89,
        region: "CAR",
        islandGroup: .luzon,
        difficultyLevel: "3/9",
        trailClass: "Class 1-2"
    ))
}
