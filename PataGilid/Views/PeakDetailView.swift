//
//  PeakDetailView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/27/26.
//

import SwiftUI

/// An in-depth summit dashboard presenting coordinates, difficulty metrics, regional classification, and logging triggers.
struct PeakDetailView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    let mountain: Mountain
    @State private var showingLogModal: Bool = false
    /// Regenerated on every toolbar tap to guarantee a fresh @StateObject in the sheet.
    @State private var logSessionId = UUID()
    
    @AppStorage("preferredMapApp") private var preferredMapApp: String = "unset"
    @State private var showingMapOptions: Bool = false
    @State private var showCopiedToast: Bool = false
    
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
                        VStack(alignment: .leading, spacing: 8) {
                            Text(mountain.name)
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
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
                    }
                    .padding(20)
                }
                .padding(.top, 8)
                
                // Specs Grid
                VStack(alignment: .leading, spacing: 14) {
                    Text("Summit Specifications")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        SpecCard(title: "Difficulty", value: mountain.difficultyLevel, icon: "gauge.medium", color: .gliderBlue)
                        SpecCard(title: "Trail Class", value: mountain.trailClass, icon: "figure.hiking", color: .summitSteel)
                    }
                    
                    SpecCard(
                        title: "Coordinates",
                        value: String(format: "%.4f, %.4f", mountain.latitude, mountain.longitude),
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
                }
                
                // Description Box
                VStack(alignment: .leading, spacing: 10) {
                    Text("Mountain Overview")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(mountain.description)
                        .font(.body)
                        .lineSpacing(4)
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle(mountain.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    logSessionId = UUID()
                    showingLogModal = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showingLogModal) {
            HikeLogCreationView(mountain: mountain)
                .id(logSessionId)
                .environmentObject(authViewModel)
        }
        .onDisappear {
            if !showingLogModal {
                // Commit-on-Climb: Evaporate uncommitted staged peak if user navigates away without recording an ascent
                PeaksViewModel.shared?.discardStagedMountainIfNeeded(mountain)
            }
        }
        .confirmationDialog("Map Navigation Options", isPresented: $showingMapOptions, titleVisibility: .visible) {
            Button("Open in Apple Maps") {
                if preferredMapApp == "unset" {
                    preferredMapApp = "apple"
                }
                openAppleMaps()
            }
            
            Button("Open in Google Maps") {
                if preferredMapApp == "unset" {
                    preferredMapApp = "google"
                }
                openGoogleMaps()
            }
            
            Button("Copy Coordinates to Clipboard") {
                copyCoordinates()
            }
            
            if preferredMapApp != "unset" {
                Button("Reset Default Map App", role: .destructive) {
                    preferredMapApp = "unset"
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
            
            Button("Cancel", role: .cancel) { }
        } message: {
            if preferredMapApp != "unset" {
                Text("Current Default: \(preferredMapApp == "apple" ? "Apple Maps" : "Google Maps"). Hold (long press) coordinates anytime to change settings or copy.")
            } else {
                Text("Select your preferred navigation app for driving directions and satellite terrain.")
            }
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
                }
            },
            alignment: .bottom
        )
    }
    
    // MARK: - Map Jumping Helpers
    
    private func handleCoordinateTap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if preferredMapApp == "apple" {
            openAppleMaps()
        } else if preferredMapApp == "google" {
            openGoogleMaps()
        } else {
            showingMapOptions = true
        }
    }
    
    private func openAppleMaps() {
        let encodedName = mountain.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Mountain"
        let mapsURLString = "maps://?ll=\(mountain.latitude),\(mountain.longitude)&q=\(encodedName)"
        if let url = URL(string: mapsURLString) {
            UIApplication.shared.open(url, options: [:]) { success in
                if !success, let httpURL = URL(string: "http://maps.apple.com/?ll=\(mountain.latitude),\(mountain.longitude)&q=\(encodedName)") {
                    UIApplication.shared.open(httpURL)
                }
            }
        }
    }
    
    private func openGoogleMaps() {
        let encodedName = mountain.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Mountain"
        let appURLString = "comgooglemaps://?q=\(mountain.latitude),\(mountain.longitude)(\(encodedName))&zoom=14"
        let webURLString = "https://www.google.com/maps/search/?api=1&query=\(mountain.latitude),\(mountain.longitude)"
        
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
        let coordsString = String(format: "%.6f, %.6f", mountain.latitude, mountain.longitude)
        UIPasteboard.general.string = coordsString
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring()) {
            showCopiedToast = true
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

#Preview {
    NavigationStack {
        PeakDetailView(mountain: Mountain(id: "test", name: "Mount Apo", description: "The highest mountain in the Philippines.", elevationMASL: 2954, latitude: 6.9875, longitude: 125.2711, region: "Region 11 (Davao Region)", islandGroup: .mindanao, difficultyLevel: "7/9 (Major)", trailClass: "Class 2-4"))
            .environmentObject(AuthViewModel())
    }
}
