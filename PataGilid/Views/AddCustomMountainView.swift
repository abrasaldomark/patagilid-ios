//
//  AddCustomMountainView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/28/26.
//

import SwiftUI
import FirebaseAuth
import PhotosUI

struct AddCustomMountainView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var mountainsViewModel: MountainsViewModel
    
    /// Callback when a new mountain is successfully created or selected from suggestions
    var onMountainSelected: (Mountain) -> Void
    
    // Form State
    @State private var mountainName: String = ""
    @State private var elevationText: String = ""
    @State private var region: String = ""
    @State private var selectedIslandGroup: IslandGroup = .luzon
    @State private var selectedDifficulty: String = "3/9 (Minor)"
    @State private var selectedClass: String = "Class 1-2"
    @State private var descriptionText: String = ""
    
    // Photo Upload State
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoImage: UIImage?
    @State private var selectedPhotoData: Data?
    @State private var isUploadingPhoto: Bool = false
    
    // Status & Error handling
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert: Bool = false
    
    let difficulties = ["1/9 (Minor)", "2/9 (Minor)", "3/9 (Minor)", "4/9 (Minor)", "5/9 (Major)", "6/9 (Major)", "7/9 (Major)", "8/9 (Major)", "9/9 (Major)"]
    let trailClasses = ["Class 1", "Class 1-2", "Class 2", "Class 2-3", "Class 3", "Class 4", "Class 5 (Technical)"]
    
    /// Dynamically provides official Philippine regions tailored to the selected Island Group
    private var availableRegionsForSelectedIsland: [String] {
        let dynamicRegions = mountainsViewModel.publicPeaks
            .filter { $0.islandGroup == selectedIslandGroup }
            .map { $0.region }
            .removingDuplicates()
            .sorted { $0.compare($1, options: [.numeric, .caseInsensitive]) == .orderedAscending }
        
        if !dynamicRegions.isEmpty {
            return dynamicRegions
        }
        
        // Comprehensive fallback if canonical database is offline
        switch selectedIslandGroup {
        case .luzon:
            return [
                "CAR (Cordillera Administrative Region)",
                "Region 1 (Ilocos Region)",
                "Region 2 (Cagayan Valley)",
                "Region 3 (Central Luzon)",
                "Region 4A (CALABARZON)",
                "Region 4B (MIMAROPA)",
                "Region 5 (Bicol Region)",
                "NCR (National Capital Region)"
            ]
        case .visayas:
            return [
                "Region 6 (Western Visayas)",
                "Region 7 (Central Visayas)",
                "Region 8 (Eastern Visayas)"
            ]
        case .mindanao:
            return [
                "Region 9 (Zamboanga Peninsula)",
                "Region 10 (Northern Mindanao)",
                "Region 11 (Davao Region)",
                "Region 12 (SOCCSKSARGEN)",
                "Region 13 (Caraga)",
                "BARMM (Bangsamoro)"
            ]
        }
    }
    
    /// Smart suggestions based on fuzzy string match against existing canonical peaks
    private var similarPeaks: [Mountain] {
        let cleanName = mountainName
            .replacingOccurrences(of: "Mt.", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "Mount", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard cleanName.count >= 3 else { return [] }
        
        return mountainsViewModel.publicPeaks.filter { peak in
            peak.name.localizedCaseInsensitiveContains(cleanName) ||
            cleanName.localizedCaseInsensitiveContains(peak.name.replacingOccurrences(of: "Mt. ", with: ""))
        }.prefix(3).map { $0 }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Purpose Guidance Banner
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gliderBlue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Contributing to PataGilid List")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Text("Use this form to submit an unlisted mountain or trail to the national list. Your submission will be reviewed by administrators before becoming visible to all mountaineers.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.gliderBlue.opacity(0.1))
                
                // MARK: - Smart Suggest (Duplicate Prevention Banner)
                if !similarPeaks.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass.circle.fill")
                                    .foregroundColor(.orange)
                                    .font(.title3)
                                Text("Similar Mountains Found in PataGilid")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                            }
                            
                            Text("Before submitting a new entry, check if your mountain is already listed:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ForEach(similarPeaks) { peak in
                                Button {
                                    onMountainSelected(peak)
                                    dismiss()
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(peak.name)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.primary)
                                            Text("\(peak.elevationMASL) MASL • \(peak.region)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Text("Select")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(Color.gliderBlue.opacity(0.15))
                                            .foregroundColor(.gliderBlue)
                                            .cornerRadius(8)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                                Divider()
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.orange.opacity(0.1))
                }
                
                // MARK: - Core Mountain Details
                Section(header: Text("Mountain Identification")) {
                    TextField("Mountain Name (e.g. Mt. Tagapo)", text: $mountainName)
                        .autocapitalization(.words)
                    
                    TextField("Elevation in MASL (e.g. 270)", text: $elevationText)
                        .keyboardType(.numberPad)
                }
                
                // MARK: - Location & Classification
                Section(header: Text("Location")) {
                    Picker("Island Group", selection: $selectedIslandGroup) {
                        ForEach(IslandGroup.allCases) { group in
                            Text(group.rawValue).tag(group)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
                    .onChange(of: selectedIslandGroup) { _ in
                        if let first = availableRegionsForSelectedIsland.first {
                            region = first
                        }
                    }
                    
                    Picker("Region", selection: $region) {
                        ForEach(availableRegionsForSelectedIsland, id: \.self) { reg in
                            Text(reg).tag(reg)
                        }
                    }
                }
                
                // MARK: - Difficulty Ratings
                Section(header: Text("Experienced Difficulty & Terrain")) {
                    Picker("Difficulty Rating", selection: $selectedDifficulty) {
                        ForEach(difficulties, id: \.self) { diff in
                            Text(diff).tag(diff)
                        }
                    }
                    
                    Picker("Trail Class", selection: $selectedClass) {
                        ForEach(trailClasses, id: \.self) { tClass in
                            Text(tClass).tag(tClass)
                        }
                    }
                }
                
                // MARK: - Optional Description
                Section(header: Text("Brief Description (Optional)"), footer: Text("Submitted mountains are immediately available for your personal summit logs. They will display on the nationwide public list once verified by a PataGilid admin.")) {
                    TextEditor(text: $descriptionText)
                        .frame(minHeight: 80)
                }
                
                // MARK: - Personal Cover Photo
                Section(header: Text("Personal Cover Photo (Optional)"), footer: Text("Set a custom cover image for this mountain. This photo is private and visible solely on your account.")) {
                    if let uiImage = selectedPhotoImage {
                        VStack(spacing: 12) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            HStack {
                                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                    Label("Change Photo", systemImage: "arrow.triangle.2.circlepath")
                                        .font(.subheadline)
                                }
                                
                                Spacer()
                                
                                Button(role: .destructive) {
                                    selectedPhotoItem = nil
                                    selectedPhotoImage = nil
                                    selectedPhotoData = nil
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                        .font(.subheadline)
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                        .padding(.vertical, 4)
                    } else {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            HStack {
                                Image(systemName: "camera.fill")
                                    .foregroundColor(.gliderBlue)
                                Text("Add Personal Cover Photo")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .onChange(of: selectedPhotoItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                            await MainActor.run {
                                self.selectedPhotoData = data
                                self.selectedPhotoImage = image
                            }
                        }
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .onAppear {
                if region.isEmpty, let first = availableRegionsForSelectedIsland.first {
                    region = first
                }
            }
            .navigationTitle("Contribute Mountain")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Next") {
                        submitMountain()
                    }
                    .fontWeight(.bold)
                    .disabled(mountainName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || elevationText.isEmpty || isSubmitting)
                }
            }
            .overlay {
                if isSubmitting {
                    ZStack {
                        Color.black.opacity(0.35).ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.5)
                            Text(isUploadingPhoto ? "Saving photo..." : "Saving mountain...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(24)
                        .background(Color(.systemGray6).opacity(0.95))
                        .cornerRadius(16)
                        .shadow(radius: 10)
                    }
                }
            }
        }
    }
    
    private func submitMountain() {
        guard let elevation = Int(elevationText.trimmingCharacters(in: .whitespacesAndNewlines)), elevation > 0 else {
            errorMessage = "Please enter a valid numeric elevation in meters above sea level (MASL)."
            return
        }
        
        guard let userId = authViewModel.currentUser?.uid else {
            errorMessage = "You must be signed in to submit a mountain."
            return
        }
        
        isSubmitting = true
        errorMessage = nil
        
        Task {
            do {
                var uploadedPhotoUrl: String? = nil
                if let photoData = selectedPhotoData {
                    await MainActor.run { isUploadingPhoto = true }
                    let timestamp = Int(Date().timeIntervalSince1970)
                    let cleanFileName = mountainName.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "_")
                    let fileName = "Mountain_\(cleanFileName)_\(timestamp)"
                    uploadedPhotoUrl = try await GoogleDriveService.shared.uploadPhotoAsset(data: photoData, fileName: fileName)
                    await MainActor.run { isUploadingPhoto = false }
                }
                
                let newPeak = try await mountainsViewModel.submitCustomMountain(
                    name: mountainName.trimmingCharacters(in: .whitespacesAndNewlines),
                    elevationMASL: elevation,
                    region: region.trimmingCharacters(in: .whitespacesAndNewlines),
                    islandGroup: selectedIslandGroup,
                    difficultyLevel: selectedDifficulty,
                    trailClass: selectedClass,
                    contributorId: userId,
                    contributorEmail: authViewModel.currentUser?.email,
                    contributorName: authViewModel.currentUser?.displayName?.components(separatedBy: " ").first?.capitalized ?? authViewModel.currentUser?.email?.formattedFirstName,
                    description: descriptionText.isEmpty ? "Community contributed hiking trail and mountain summit." : descriptionText
                )
                
                if let driveUrl = uploadedPhotoUrl {
                    try? await UserMountainPhotoService.shared.savePhoto(for: newPeak.id, photoUrl: driveUrl)
                }
                
                await MainActor.run {
                    isSubmitting = false
                    onMountainSelected(newPeak)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "Failed to save mountain: \(error.localizedDescription)"
                }
            }
        }
    }
}
