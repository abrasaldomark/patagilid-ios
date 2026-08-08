//
//  HikeLogCreationView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/28/26.
//

import SwiftUI
import PhotosUI

/// Modal sheet for recording a climb attempt — date, outcome, trail details, and optional climb photos.
struct HikeLogCreationView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    let mountain: Mountain
    var logToEdit: HikeLog? = nil
    var onSave: ((HikeLog) -> Void)? = nil
    @StateObject private var viewModel = HikeLogViewModel()
    @Environment(\.dismiss) private var dismiss
    

    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    summitBanner
                    activityForm
                    trailDetailsForm
                    
                    photosForm
                    
                    if let error = viewModel.errorMessage {
                        errorBanner(error)
                            .padding(.bottom, 12)
                    }
                }
                .padding(.bottom, 24)
            }
            .navigationTitle(logToEdit == nil ? "Log Ascent" : "Edit Ascent Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if logToEdit == nil {
                            // Commit-on-Climb: If user cancels recording an ascent for an uncommitted custom mountain, discard it!
                            MountainsViewModel.shared?.discardStagedMountainIfNeeded(mountain)
                        }
                        dismiss()
                    }
                    .disabled(viewModel.isSaving)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.submitLog(for: mountain, editingLog: logToEdit) { updatedLog in
                            onSave?(updatedLog)
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                                .tint(.gliderBlue)
                        } else {
                            Text("Save")
                                .fontWeight(.bold)
                                .foregroundColor(.gliderBlue)
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .onChange(of: viewModel.didCompleteSuccess) { _, success in
                if success { dismiss() }
            }
            .onAppear {
                if let existing = logToEdit {
                    viewModel.setupForEditing(log: existing)
                } else {
                    if viewModel.trailDifficulty.isEmpty {
                        viewModel.trailDifficulty = mountain.difficultyLevel
                    }
                    if viewModel.trailClass.isEmpty {
                        viewModel.trailClass = mountain.trailClass
                    }
                }
            }

        }
    }
    
    // MARK: - Subviews
    
    private var summitBanner: some View {
        HStack(spacing: 16) {
            Image(systemName: "mountain.2.fill")
                .font(.system(size: 28))
                .foregroundColor(.gliderBlue)
                .frame(width: 56, height: 56)
                .background(Color.gliderBlue.opacity(0.12))
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
                    .foregroundColor(.summitSteel)
                
                Text(mountain.region)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding()
        .background(Color.secondary.opacity(0.06))
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
                        outcomeCard(.backedOut)
                    }
                }
                .padding()
            }
            .background(Color.secondary.opacity(0.06))
            .cornerRadius(14)
            .padding(.horizontal)
        }
    }
    
    private var trailDetailsForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trail Details")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                // Route Style Selector (Back Trail vs Traverse)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Route Style")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        routeStyleCard(title: "Back Trail", subtitle: "Same Start & Exit", icon: "point.forward.to.point.capsulepath", isTraverse: false, accentColor: .blue)
                        routeStyleCard(title: "Traverse", subtitle: "Different Exit Trail", icon: "point.bottomleft.forward.to.point.topright.scurvepath", isTraverse: true, accentColor: .purple)
                    }
                }
                .padding()
                
                Divider().padding(.leading)
                
                // Trail / Entry Route Name
                HStack(spacing: 12) {
                    Image(systemName: viewModel.isTraverse ? "arrow.down.right.circle.fill" : "point.forward.to.point.capsulepath")
                        .foregroundColor(.summitSteel)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.isTraverse ? "Start Trail" : "Back Trail Name (Start & Exit)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField(viewModel.isTraverse ? "e.g. Kule Trail" : "e.g. Salacafe Trail, Ambangeg Trail", text: $viewModel.trailName)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
                .padding()
                
                // Exit Trail (Only visible if Traverse is ON)
                if viewModel.isTraverse {
                    Divider().padding(.leading)
                    
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.up.right.circle.fill")
                            .foregroundColor(.red)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Exit Trail")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("e.g. Salacafe Trail", text: $viewModel.exitTrailName)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding()
                }
                
                Divider().padding(.leading)
                
                // Trail Difficulty
                HStack(spacing: 12) {
                    Image(systemName: "gauge.with.dots.needle.bottom.100percent")
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Experienced Difficulty")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g. 3/9 (Minor), 7/9 (Major)", text: $viewModel.trailDifficulty)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
                .padding()
                
                Divider().padding(.leading)
                
                // Trail Class
                HStack(spacing: 12) {
                    Image(systemName: "figure.climbing")
                        .foregroundColor(.summitSteel)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Technical Trail Class")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g. Class 1-2, Class 3", text: $viewModel.trailClass)
                            .font(.subheadline)
                            .foregroundColor(.primary)
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
    private func routeStyleCard(title: String, subtitle: String, icon: String, isTraverse: Bool, accentColor: Color) -> some View {
        let isSelected = (viewModel.isTraverse == isTraverse)
        
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.isTraverse = isTraverse
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? accentColor : .gray)
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? accentColor : .gray)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 4)
            .background(isSelected ? accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
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
                Text(option == .summited ? "Reached Top" : "Did Not Finish")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 4)
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
    
    private var photosForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Climb Photos")
                    .font(.headline)
                Spacer()
                if viewModel.totalPhotosCount > 0 {
                    Text("\(viewModel.totalPhotosCount) photo\(viewModel.totalPhotosCount == 1 ? "" : "s")")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            VStack(spacing: 16) {
                if viewModel.totalPhotosCount > 0 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(viewModel.existingPhotoUrls.enumerated()), id: \.offset) { index, urlString in
                                ZStack(alignment: .topTrailing) {
                                    CachedAsyncImage(url: URL(string: urlString)) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image.resizable().scaledToFill()
                                        default:
                                            Color.secondary.opacity(0.1)
                                        }
                                    }
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                                    
                                    Button {
                                        withAnimation {
                                            viewModel.removeExistingImage(at: index)
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
                
                PhotosPicker(
                    selection: $viewModel.selectedPhotos,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    HStack(spacing: 10) {
                        Image(systemName: "photo.badge.plus")
                            .font(.title3)
                        Text(viewModel.totalPhotosCount == 0 ? "Add Photos" : "Change / Add Photos")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.gliderBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.gliderBlue.opacity(0.12))
                    .cornerRadius(12)
                    .padding(.horizontal, viewModel.totalPhotosCount == 0 ? 0 : 8)
                }
                .onChange(of: viewModel.selectedPhotos) { _, _ in
                    Task {
                        await viewModel.loadPhotos()
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
    .environmentObject(AuthViewModel())
}
