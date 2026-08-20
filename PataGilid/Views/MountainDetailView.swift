//
//  MountainDetailView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/27/26.
//

import SwiftUI
import SwiftData
import FirebaseFirestore
import FirebaseAuth
import MapKit
import PhotosUI
import GooglePlaces

/// An in-depth summit dashboard presenting coordinates, difficulty metrics, regional classification, and crowdsourced GPS calibration triggers.
struct MountainDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var listsViewModel: MountainListsViewModel
    @ObservedObject private var userPhotoService = UserMountainPhotoService.shared
    
    @Query private var lists: [MountainList]
    
    let mountain: Mountain
    let initialShowLogModal: Bool
    
    @State private var showingLogModal: Bool = false
    @State private var hasAutoOpenedLog: Bool = false
    
    init(mountain: Mountain, initialShowLogModal: Bool = false) {
        self.mountain = mountain
        self.initialShowLogModal = initialShowLogModal
    }
    
    /// Regenerated on every toolbar tap to guarantee a fresh @StateObject in the sheet.
    @State private var logSessionId = UUID()
    @State private var showSaveToListSheet: Bool = false
    
    @State private var showingMapOptions: Bool = false
    @State private var showingInternalMap: Bool = false
    @State private var showingCoordinateContribution: Bool = false
    @State private var showCopiedToast: Bool = false
    @State private var showingEditModal: Bool = false
    
    @State private var selectedCoverPhotoItem: PhotosPickerItem?
    @State private var isUploadingCoverPhoto: Bool = false
    @State private var showPhotoUploadSuccessToast: Bool = false
    @State private var displayIsSaved: Bool = false
    
    private var isSaved: Bool {
        lists.contains(where: { $0.mountainIds.contains(mountain.id) })
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header Hero Box
                ZStack {
                    MountainHeaderImageView(mountain: mountain, isThumbnail: false)
                    
                    VStack(alignment: .leading, spacing: 0) {
                        // Top Badges
                        HStack(spacing: 8) {
                            Text(mountain.islandGroup.rawValue.uppercased())
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.gliderBlue)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                            
                            if !mountain.isPubliclyApproved {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock.badge.fill")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("Pending Review")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                            }
                            
                            Spacer()
                        }
                        
                        Spacer()
                        
                        // Bottom Title & Specifications Stack
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(mountain.name)
                                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                                    .lineSpacing(4)
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "triangle.tophalf.filled")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(Color.summitSteel)
                                        Text("\(mountain.elevationMASL) MASL")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                    }
                                    
                                    HStack(spacing: 6) {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(Color.gliderBlue)
                                        Text(mountain.region)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.white.opacity(0.9))
                                            .lineLimit(1)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            Button {
                                showSaveToListSheet = true
                            } label: {
                                Image(systemName: displayIsSaved ? "heart.fill" : "heart")
                                    .font(.system(size: 28))
                                    .foregroundColor(displayIsSaved ? .red : .white)
                                    .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                                    .scaleEffect(displayIsSaved ? 1.15 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0), value: displayIsSaved)
                            }
                            .padding(.bottom, 4)
                        }
                    }
                    .padding(20)
                }
                .padding(.top, 8)
                
                // Specs Grid & Crowdsourced GPS Banner
                VStack(alignment: .leading, spacing: 14) {
                    Text("Summit Specifications")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        SpecCard(title: "Difficulty", value: mountain.difficultyLevel, icon: "gauge.medium", color: .gliderBlue)
                        SpecCard(title: "Trail Class", value: mountain.trailClass, icon: "figure.hiking", color: .summitSteel)
                    }
                    
                    if let lat = mountain.latitude, let lon = mountain.longitude {
                        SpecCard(
                            title: "Coordinates",
                            value: String(format: "%.4f, %.4f", lat, lon),
                            icon: "location.circle.fill",
                            color: .gliderBlue,
                            isInteractive: true
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            handleCoordinateTap()
                        }
                        .onLongPressGesture {
                            showingMapOptions = true
                        }
                        
                        if mountain.isVerifiedByCommunity {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.gliderBlue)
                                Text("GPS Verified by \(mountain.communityVerifications) Explorer\(mountain.communityVerifications == 1 ? "" : "s")")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.gliderBlue.opacity(0.12))
                            .cornerRadius(12)
                        }
                    } else if mountain.pendingCalibrationsCount > 0 {
                        pendingCalibrationBanner
                    } else {
                        crowdsourcedGPSBanner
                    }
                }
                
                // Description Box
                VStack(alignment: .leading, spacing: 10) {
                    Text("Mountain Overview")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(mountain.descriptionText)
                        .font(.body)
                        .lineSpacing(4)
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(12)
                }
                
                // Mountain Cover Photo Upload Box
                if mountain.isPubliclyApproved {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Mountain Photography")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: "photo.stack.fill")
                                    .font(.title2)
                                    .foregroundColor(.gliderBlue)
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(userPhotoService.photoUrl(for: mountain.id) == nil ? "Add Personal Cover Photo" : "Personal Cover Photo Set")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                    Text("Set a private cover photo for this mountain. This image is visible only on your account.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            PhotosPicker(selection: $selectedCoverPhotoItem, matching: .images) {
                                HStack {
                                    Spacer()
                                    Image(systemName: isUploadingCoverPhoto ? "arrow.triangle.2.circlepath.camera.fill" : "camera.fill")
                                    Text(isUploadingCoverPhoto ? "Saving photo..." : (userPhotoService.photoUrl(for: mountain.id) == nil ? "Upload Photo" : "Update Photo"))
                                        .fontWeight(.bold)
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                                .background(Color.gliderBlue)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .disabled(isUploadingCoverPhoto || authViewModel.currentUser == nil)
                            
                            if authViewModel.currentUser == nil {
                                Text("Please sign in to set a personal cover photo.")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(14)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.gliderBlue.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.bottom, 20)
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle(mountain.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 8) {
                    if !mountain.isPubliclyApproved, let email = authViewModel.currentUser?.email, mountain.contributorEmail == email {
                        Button {
                            showingEditModal = true
                        } label: {
                            Text("Edit")
                                .fontWeight(.semibold)
                                .foregroundColor(.gliderBlue)
                        }
                    }
                    if mountain.isPubliclyApproved {
                        Button {
                            logSessionId = UUID()
                            showingLogModal = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(.gliderBlue)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingLogModal) {
            HikeLogCreationView(mountain: mountain)
                .id(logSessionId)
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showingEditModal) {
            NavigationStack {
                AddCustomMountainView(
                    onMountainSubmitted: { _, _, _ in
                        showingEditModal = false
                    },
                    editingMountain: mountain
                )
            }
        }
        .sheet(isPresented: $showSaveToListSheet) {
            SaveToListSheet(mountainId: mountain.id)
                .environmentObject(listsViewModel)
        }
        .sheet(isPresented: $showingInternalMap) {
            MountainMapView(mountain: mountain)
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showingCoordinateContribution) {
            CoordinateContributionView(mountain: mountain)
                .environmentObject(authViewModel)
        }
        .onAppear {
            displayIsSaved = isSaved
            if initialShowLogModal && !hasAutoOpenedLog {
                showingLogModal = true
                hasAutoOpenedLog = true
            }
        }
        .onChange(of: showSaveToListSheet) { _, isShowing in
            if !isShowing {
                displayIsSaved = isSaved
            }
        }
        .confirmationDialog("More Coordinate Options", isPresented: $showingMapOptions, titleVisibility: .visible) {
            if mountain.latitude != nil && mountain.longitude != nil {
                Button("Copy Coordinates to Clipboard") {
                    copyCoordinates()
                }
                
                Button("Open in Apple Maps") {
                    openAppleMaps()
                }
                
                Button("Open in Google Maps") {
                    openGoogleMaps()
                }
            }
            
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Tap coordinates directly to view in MapKit, or hold here for external directions & clipboard copy.")
        }
        .overlay(
            Group {
                if showCopiedToast {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.gliderBlue)
                        Text("Coordinates Copied!")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.systemBackground).opacity(0.95))
                    .foregroundColor(.primary)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showCopiedToast = false
                            }
                        }
                    }
                    .padding(.bottom, 30)
                } else if showPhotoUploadSuccessToast {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.gliderBlue)
                        Text("Personal Cover Photo Updated!")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.systemBackground).opacity(0.95))
                    .foregroundColor(.primary)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showPhotoUploadSuccessToast = false
                            }
                        }
                    }
                    .padding(.bottom, 30)
                }
            },
            alignment: .bottom
        )
        .onChange(of: selectedCoverPhotoItem) { _, newItem in
            guard let newItem = newItem else { return }
            Task {
                await MainActor.run { isUploadingCoverPhoto = true }
                do {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        let timestamp = Int(Date().timeIntervalSince1970)
                        let cleanName = mountain.name.replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: ".", with: "")
                        let fileName = "Mountain_\(cleanName)_\(timestamp)"
                        let driveUrl = try await GoogleDriveService.shared.uploadPhotoAsset(data: data, fileName: fileName)
                        
                        // Save exclusively to the active user's personal profile collection & local memory
                        try await UserMountainPhotoService.shared.savePhoto(for: mountain.id, photoUrl: driveUrl)
                        
                        await MainActor.run {
                            isUploadingCoverPhoto = false
                            withAnimation { showPhotoUploadSuccessToast = true }
                        }
                    } else {
                        await MainActor.run { isUploadingCoverPhoto = false }
                    }
                } catch {
                    await MainActor.run {
                        print("❌ Failed to upload cover photo: \(error.localizedDescription)")
                        isUploadingCoverPhoto = false
                    }
                }
            }
        }
    }
    
    // MARK: - Crowdsourced GPS Banners
    
    @ViewBuilder
    private var pendingCalibrationBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("GPS Calibration Pending")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text("\(mountain.pendingCalibrationsCount) summit location(s) have been submitted for this mountain and are currently awaiting admin verification.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    @ViewBuilder
    private var crowdsourcedGPSBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.title2)
                    .foregroundColor(.gliderBlue)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Help Map This Summit")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text("Be the first hiker to pin this mountain! Locate its summit directly on the map to help complete our mountain list.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Button {
                showingCoordinateContribution = true
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                    Text("Pin Summit Location")
                        .fontWeight(.bold)
                    Spacer()
                }
                .padding(.vertical, 10)
                .background(Color.gliderBlue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(14)
        .background(Color.gliderBlue.opacity(0.12))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.gliderBlue.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Map Jumping Helpers
    
    private func handleCoordinateTap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showingInternalMap = true
    }
    
    private func openAppleMaps() {
        guard let lat = mountain.latitude, let lon = mountain.longitude else { return }
        let encodedName = mountain.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Mountain"
        let mapsURLString = "maps://?ll=\(lat),\(lon)&q=\(encodedName)"
        if let url = URL(string: mapsURLString) {
            UIApplication.shared.open(url, options: [:]) { success in
                if !success, let httpURL = URL(string: "http://maps.apple.com/?ll=\(lat),\(lon)&q=\(encodedName)") {
                    UIApplication.shared.open(httpURL)
                }
            }
        }
    }
    
    private func openGoogleMaps() {
        guard let lat = mountain.latitude, let lon = mountain.longitude else { return }
        let encodedName = mountain.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Mountain"
        let appURLString = "comgooglemaps://?q=\(lat),\(lon)(\(encodedName))&zoom=14"
        let webURLString = "https://www.google.com/maps/search/?api=1&query=\(lat),\(lon)"
        
        if let appURL = URL(string: appURLString) {
            UIApplication.shared.open(appURL, options: [:]) { success in
                if !success, let webURL = URL(string: webURLString) {
                    UIApplication.shared.open(webURL)
                }
            }
        } else if let webURL = URL(string: webURLString) {
            UIApplication.shared.open(webURL)
        }
    }
    
    private func copyCoordinates() {
        guard let lat = mountain.latitude, let lon = mountain.longitude else { return }
        let coordsString = String(format: "%.6f, %.6f", lat, lon)
        UIPasteboard.general.string = coordsString
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring()) {
            showCopiedToast = true
        }
    }
}

/// Modal dialog allowing hikers to contribute verified GPS coordinates for unmapped peaks.
struct CoordinateContributionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    let mountain: Mountain
    
    @State private var latString: String = ""
    @State private var lonString: String = ""
    @State private var editedRegion: String
    @State private var showingMapPicker: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String? = nil
    
    init(mountain: Mountain) {
        self.mountain = mountain
        _editedRegion = State(initialValue: mountain.region)
    }
    
    private var availableRegions: [String] {
        var defaultRegions = [
            "NCR – National Capital Region (Metro Manila)",
            "CAR – Cordillera Administrative Region",
            "Region 1 – Ilocos Region",
            "Region 2 – Cagayan Valley",
            "Region 3 – Central Luzon",
            "Region 4-A – CALABARZON",
            "MIMAROPA – Southwestern Tagalog Region",
            "Region 5 – Bicol Region",
            "Region 6 – Western Visayas",
            "NIR – Negros Island Region",
            "Region 7 – Central Visayas",
            "Region 8 – Eastern Visayas",
            "Region 9 – Zamboanga Peninsula",
            "Region 10 – Northern Mindanao",
            "Region 11 – Davao Region",
            "Region 12 – SOCCSKSARGEN",
            "Region 13 – Caraga",
            "BARMM – Bangsamoro Autonomous Region in Muslim Mindanao"
        ]
        if !defaultRegions.contains(mountain.region) && !mountain.region.isEmpty {
            defaultRegions.append(mountain.region)
        }
        return defaultRegions.sorted { $0.compare($1, options: [.numeric, .caseInsensitive]) == .orderedAscending }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Target Summit"), footer: Text("Submissions are reviewed by our moderation team to verify map integrity before updating public mountain markers.")) {
                    HStack {
                        Text("Mountain Name")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(mountain.name)
                            .fontWeight(.bold)
                    }
                    Picker("Region / Province", selection: $editedRegion) {
                        ForEach(availableRegions, id: \.self) { reg in
                            Text(reg).tag(reg)
                        }
                    }
                }
                
                Section(header: Text("Summit Location"), footer: Text("Tap 'Pin on Map' to visually locate and pin the mountain summit.")) {
                    Button {
                        showingMapPicker = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Pin on Map")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.gliderBlue)
                    
                    if let lat = Double(latString.trimmingCharacters(in: .whitespaces)), let lon = Double(lonString.trimmingCharacters(in: .whitespaces)) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            Text(String(format: "Pinned Summit: %.5f° N, %.5f° E", lat, lon))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.slash")
                                .foregroundColor(.secondary)
                            Text("No location pinned yet. Tap above to select on map.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                }
                
                if let err = errorMessage {
                    Section {
                        Text(err)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button {
                        submitCoordinates()
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                            } else {
                                Text("Submit for Admin Review")
                                    .fontWeight(.bold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(latString.trimmingCharacters(in: .whitespaces).isEmpty || lonString.trimmingCharacters(in: .whitespaces).isEmpty || editedRegion.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
                }
            }
            .navigationTitle("Contribute GPS")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if editedRegion.isEmpty {
                    editedRegion = mountain.region
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingMapPicker) {
                InteractiveCoordinatePickerView(
                    peakName: mountain.name,
                    initialLat: Double(latString.trimmingCharacters(in: .whitespaces)),
                    initialLon: Double(lonString.trimmingCharacters(in: .whitespaces))
                ) { newCoord in
                    latString = String(format: "%.6f", newCoord.latitude)
                    lonString = String(format: "%.6f", newCoord.longitude)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
        }
    }
    
    private func submitCoordinates() {
        errorMessage = nil
        guard let lat = Double(latString.trimmingCharacters(in: .whitespaces)),
              let lon = Double(lonString.trimmingCharacters(in: .whitespaces)),
              (-90.0...90.0).contains(lat),
              (-180.0...180.0).contains(lon) else {
            errorMessage = "Please tap 'Pin on Map' to select the mountain's summit."
            return
        }
        
        isSubmitting = true
        Task {
            let email = authViewModel.currentUser?.email ?? "Anonymous Explorer"
            let firstName = authViewModel.currentUser?.displayName?.components(separatedBy: " ").first?.capitalized ?? email.formattedFirstName
            let regionTrimmed = editedRegion.trimmingCharacters(in: .whitespacesAndNewlines)
            
            do {
                try await MountainsViewModel.shared?.submitGPSCalibration(for: mountain, lat: lat, lon: lon, userEmail: email, userName: firstName)
                
                await MainActor.run {
                    isSubmitting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to submit coordinates: \(error.localizedDescription)"
                    isSubmitting = false
                }
            }
        }
    }
}

struct SpecCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var isInteractive: Bool = false
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            Spacer(minLength: 0)
            
            if isInteractive {
                Image(systemName: "arrow.up.right.circle.fill")
                    .font(.title3)
                    .foregroundColor(color.opacity(0.85))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(12)
    }
}

/// A MapKit view where users can tap anywhere on satellite imagery to pin a mountain's summit and extract coordinates.
struct InteractiveCoordinatePickerView: View {
    let peakName: String
    @Environment(\.dismiss) private var dismiss
    @State private var mapCenter: CLLocationCoordinate2D
    @State private var mapDistance: CLLocationDistance
    @State private var cameraTrigger: UUID = UUID()
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    @State private var searchError: String? = nil
    @State private var showInstructionBanner: Bool = true
    let onSelect: (CLLocationCoordinate2D) -> Void
    
    init(peakName: String, initialLat: Double?, initialLon: Double?, onSelect: @escaping (CLLocationCoordinate2D) -> Void) {
        self.peakName = peakName
        self.onSelect = onSelect
        if let lat = initialLat, let lon = initialLon, (-90.0...90.0).contains(lat), (-180.0...180.0).contains(lon) {
            let center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            _selectedCoordinate = State(initialValue: center)
            _mapCenter = State(initialValue: center)
            _mapDistance = State(initialValue: 5000)
        } else {
            // Geographic center of the Philippines
            let center = CLLocationCoordinate2D(latitude: 12.8797, longitude: 121.7740)
            _mapCenter = State(initialValue: center)
            _mapDistance = State(initialValue: 1_200_000)
        }
    }
    
    var body: some View {
        NavigationStack {
            GoogleMapView(
                centerCoordinate: mapCenter,
                distance: mapDistance,
                annotationCoordinate: selectedCoordinate,
                annotationTitle: peakName,
                isInteractivePicker: true,
                isDraggableAnnotation: false,
                onAnnotationDrag: { newCoord in
                    withAnimation(.spring()) {
                        selectedCoordinate = newCoord
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                },
                cameraTrigger: cameraTrigger
            )
            .edgesIgnoringSafeArea(.all)
            .navigationTitle("Pin Summit Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .top) {
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gliderBlue)
                        TextField("Search mountain, summit, or trail...", text: $searchText)
                            .submitLabel(.search)
                            .onSubmit {
                                performSearch()
                            }
                        
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                                searchError = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if isSearching {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if !searchText.isEmpty {
                            Button("Go") {
                                performSearch()
                            }
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.gliderBlue)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.systemBackground).opacity(0.95))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                    .padding(.horizontal)
                    .padding(.top, 6)
                    
                    if let error = searchError {
                        Text(error)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.85))
                            .clipShape(Capsule())
                            .padding(.top, 6)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if selectedCoordinate != nil || showInstructionBanner {
                    VStack(spacing: 12) {
                        if let selected = selectedCoordinate {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Selected Coordinates")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(String(format: "%.6f, %.6f", selected.latitude, selected.longitude))
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                }
                                Spacer()
                                Button {
                                    onSelect(selected)
                                    dismiss()
                                } label: {
                                    Text("Save Pin")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(Color.gliderBlue)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                            }
                        } else {
                            HStack(spacing: 12) {
                                Image(systemName: "hand.tap.fill")
                                    .font(.title3)
                                    .foregroundColor(.gliderBlue)
                                    Text("Tap anywhere on the map to place a pin on the mountain's summit.")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Spacer(minLength: 0)
                                Button {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        showInstructionBanner = false
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.secondary.opacity(0.8))
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(.systemBackground).opacity(0.95))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: -4)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
    
    private func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        
        isSearching = true
        searchError = nil
        
        let filter = GMSAutocompleteFilter()
        filter.country = "PH"
        
        GMSPlacesClient.shared().findAutocompletePredictions(fromQuery: query, filter: filter, sessionToken: nil) { (results, error) in
            if let error = error {
                isSearching = false
                searchError = "Search failed: \(error.localizedDescription)"
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation { searchError = nil }
                }
                return
            }
            
            guard let firstResult = results?.first else {
                isSearching = false
                searchError = "Location not found via Google Places. Try a simpler name."
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation { searchError = nil }
                }
                return
            }
            
            let fields: GMSPlaceField = GMSPlaceField(rawValue: UInt64(GMSPlaceField.coordinate.rawValue))
            GMSPlacesClient.shared().fetchPlace(fromPlaceID: firstResult.placeID, placeFields: fields, sessionToken: nil) { (place, error) in
                isSearching = false
                if let error = error {
                    searchError = "Failed to fetch details: \(error.localizedDescription)"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation { searchError = nil }
                    }
                    return
                }
                
                if let coordinate = place?.coordinate {
                    mapCenter = coordinate
                    mapDistance = 5000
                    cameraTrigger = UUID()
                    withAnimation(.spring()) {
                        selectedCoordinate = coordinate
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        MountainDetailView(mountain: Mountain(id: "test", name: "Mount Apo", description: "The highest mountain in the Philippines.", elevationMASL: 2954, latitude: 6.9875, longitude: 125.2711, region: "Region 11 (Davao Region)", islandGroup: .mindanao, difficultyLevel: "7/9 (Major)", trailClass: "Class 2-4"))
            .environmentObject(AuthViewModel())
    }
}
