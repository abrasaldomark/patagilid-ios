//
//  AddCustomMountainView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/28/26.
//

import SwiftUI
import FirebaseAuth
struct AddCustomMountainView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var mountainsViewModel: MountainsViewModel
    
    /// Callback when a new mountain is successfully created or selected from suggestions
    var onMountainSelected: (Mountain) -> Void
    
    // Form State
    @State private var mountainName: String = ""
    @State private var elevationText: String = ""
    @State private var isFetchingElevation: Bool = false
    @State private var selectedCoordinate: CLLocationCoordinate2D? = nil
    @State private var selectedPlaceName: String? = nil
    @State private var region: String = ""
    @State private var selectedIslandGroup: IslandGroup = .luzon
    @State private var selectedDifficulty: String = "3/9 (Minor)"
    @State private var selectedClass: String = "Class 1-2"
    @State private var descriptionText: String = ""
    
    // Map State
    @State private var isMapPresented: Bool = false
    @State private var showOutsidePHAlert: Bool = false
    
    // Status & Error handling
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert: Bool = false
    @State private var showInfoCard: Bool = true
    
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
                if showInfoCard {
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
                                Text("Submit an unlisted mountain. It will be reviewed by admins before becoming public.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            Button(action: { showInfoCard = false }) {
                                Image(systemName: "xmark")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.gliderBlue.opacity(0.1))
                }
                
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
                
                // MARK: - Core Mountain Details & Location
                Section(header: Text("Mountain Information")) {
                    Button(action: {
                        isMapPresented = true
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "map.fill")
                            Text(selectedCoordinate != nil ? "Edit Pinned Location" : "Pin Location on Map")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .foregroundColor(.white)
                    .listRowBackground(Color.gliderBlue)
                    
                    if let coord = selectedCoordinate {
                        HStack {
                            Text("Pinned Location")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(String(format: "%.4f, %.4f", coord.latitude, coord.longitude))
                                .foregroundColor(.secondary)
                        }
                        .font(.subheadline)
                    }
                    
                    TextField("Mountain Name (e.g. Mt. Tagapo)", text: $mountainName)
                        .autocapitalization(.words)
                    
                    ZStack(alignment: .trailing) {
                        TextField("Elevation in MASL (e.g. 270)", text: $elevationText)
                            .keyboardType(.numberPad)
                        
                        if isFetchingElevation {
                            ProgressView()
                        }
                    }
                    
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
                Section(header: Text("Difficulty & Terrain")) {
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
                
                // MARK: - Submit Button
                Section {
                    Button(action: submitCustomMountain) {
                        HStack {
                            Spacer()
                            Image(systemName: "mountain.2.fill")
                            Text("Submit Mountain for Moderation")
                                .fontWeight(.bold)
                            Spacer()
                        }
                    }
                    .disabled(mountainName.isEmpty || elevationText.isEmpty || isSubmitting)
                    .listRowBackground(
                        (mountainName.isEmpty || elevationText.isEmpty) ? Color.gray.opacity(0.3) : Color.gliderBlue
                    )
                    .foregroundColor(
                        (mountainName.isEmpty || elevationText.isEmpty) ? Color(uiColor: .systemGray) : .white
                    )
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
            }
            .fullScreenCover(isPresented: $isMapPresented) {
                CoordinateSelectionView(selectedCoordinate: $selectedCoordinate, selectedPlaceName: $selectedPlaceName)
            }
            .alert(errorMessage?.contains("already on PataGilid") == true ? "Teka, sandali!" : "Notice", isPresented: Binding<Bool>(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
            .onChange(of: selectedCoordinate) { _, newCoord in
                guard let newCoord = newCoord else { return }
                
                if let placeName = selectedPlaceName, !placeName.isEmpty {
                    self.mountainName = placeName
                }
                
                LocationHelper.reverseGeocode(coordinate: newCoord) { newName, newRegion, newIslandGroup in
                    DispatchQueue.main.async {
                        if let r = newRegion, let ig = newIslandGroup {
                            self.selectedIslandGroup = ig
                            // Wait a tiny bit for the regions list to update based on island group, then set region
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                self.region = r
                            }
                            if self.mountainName.isEmpty {
                                if let name = newName, !name.isEmpty, !name.contains("+") {
                                    self.mountainName = name
                                }
                            }
                            
                            // Fetch elevation
                            self.isFetchingElevation = true
                            LocationHelper.fetchElevation(coordinate: newCoord) { elevation in
                                DispatchQueue.main.async {
                                    self.isFetchingElevation = false
                                    if let elevation = elevation, self.elevationText.isEmpty {
                                        self.elevationText = String(Int(elevation))
                                    }
                                }
                            }
                        } else {
                            // Invalid location (e.g. outside PH or ocean)
                            self.selectedCoordinate = nil
                            self.showOutsidePHAlert = true
                        }
                    }
                }
            }
            .alert("Invalid Location", isPresented: $showOutsidePHAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The pinned location appears to be outside the Philippines or in an undefined area. Please pin a valid location on land within the country.")
            }
            .alert("Success", isPresented: $showSuccessAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your mountain contribution has been successfully submitted and is now pending review.")
            }
            .overlay {
                if isSubmitting {
                    ZStack {
                        Color.black.opacity(0.35).ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.5)
                            Text("Saving mountain...")
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
    
    private func submitCustomMountain() {
        let cleanInputName = mountainName
            .replacingOccurrences(of: "Mt.", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "Mount", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            
        let isDuplicate = mountainsViewModel.publicPeaks.contains { peak in
            let cleanDbName = peak.name
                .replacingOccurrences(of: "Mt.", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "Mount", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return cleanDbName.caseInsensitiveCompare(cleanInputName) == .orderedSame
        }
        
        if isDuplicate {
            let trimmedName = mountainName.trimmingCharacters(in: .whitespacesAndNewlines)
            errorMessage = "\"\(trimmedName)\" is already on PataGilid. Please check the name or try another peak."
            return
        }

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
                let mountainId = UUID().uuidString
                let newMountain = Mountain(
                    id: mountainId,
                    name: mountainName.trimmingCharacters(in: .whitespacesAndNewlines),
                    descriptionText: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
                    elevationMASL: elevation,
                    latitude: selectedCoordinate?.latitude,
                    longitude: selectedCoordinate?.longitude,
                    region: region,
                    islandGroup: selectedIslandGroup,
                    difficultyLevel: selectedDifficulty,
                    trailClass: selectedClass,
                    contributorId: userId,
                    contributorEmail: authViewModel.currentUser?.email,
                    contributorName: authViewModel.currentUser?.displayName?.components(separatedBy: " ").first?.capitalized ?? authViewModel.currentUser?.email?.formattedFirstName,
                    description: descriptionText.isEmpty ? "Community contributed hiking trail and mountain summit." : descriptionText
                )
                
                // Add to firestore
                try await mountainsViewModel.addCustomMountain(newMountain)
                
                await MainActor.run {
                    isSubmitting = false
                    onMountainSelected(newMountain)
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
