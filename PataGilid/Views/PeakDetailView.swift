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
                                .background(Color.emeraldGreen)
                                .foregroundColor(.black)
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
                                        .foregroundColor(Color.emeraldGreen)
                                    Text("\(mountain.elevationMASL) MASL")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                
                                HStack(spacing: 6) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Color.emeraldGreen)
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
                        SpecCard(title: "Difficulty", value: mountain.difficultyLevel, icon: "gauge.medium", color: .orange)
                        SpecCard(title: "Trail Class", value: mountain.trailClass, icon: "figure.hiking", color: .green)
                        SpecCard(title: "Latitude", value: String(format: "%.4f° N", mountain.latitude), icon: "location.north.circle.fill", color: .teal)
                        SpecCard(title: "Longitude", value: String(format: "%.4f° E", mountain.longitude), icon: "globe.asia.australia.fill", color: .blue)
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
    }
}

struct SpecCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
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
