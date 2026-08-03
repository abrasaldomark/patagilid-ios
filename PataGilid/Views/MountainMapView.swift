//
//  MountainMapView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/30/26.
//

import SwiftUI
import MapKit
import SwiftData
import FirebaseFirestore
import Combine

/// A responsive, offline-capable internal MapKit viewing modal for inspecting peak terrain and coordinates, with Admin drag-and-drop moderation superpowers.
struct MountainMapView: View {
    let mountain: Mountain
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var center: CLLocationCoordinate2D
    @State private var distance: CLLocationDistance
    @State private var cameraTrigger: UUID = UUID()
    @State private var adjustedCoordinate: CLLocationCoordinate2D? = nil
    @State private var isSaving: Bool = false
    
    private var displayLatitude: Double? { adjustedCoordinate?.latitude ?? mountain.latitude ?? mountain.pendingLatitude }
    private var displayLongitude: Double? { adjustedCoordinate?.longitude ?? mountain.longitude ?? mountain.pendingLongitude }
    private var isPending: Bool { mountain.latitude == nil && mountain.pendingLatitude != nil }
    
    init(mountain: Mountain) {
        self.mountain = mountain
        if let lat = mountain.latitude ?? mountain.pendingLatitude, let lon = mountain.longitude ?? mountain.pendingLongitude {
            _center = State(initialValue: CLLocationCoordinate2D(latitude: lat, longitude: lon))
            _distance = State(initialValue: 5000)
        } else {
            // Geographic center of the Philippines fallback if awaiting coordinates
            _center = State(initialValue: CLLocationCoordinate2D(latitude: 12.8797, longitude: 121.7740))
            _distance = State(initialValue: 1_200_000)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                OpenTopoMapView(
                    centerCoordinate: center,
                    distance: distance,
                    annotationCoordinate: (displayLatitude != nil && displayLongitude != nil) ? CLLocationCoordinate2D(latitude: displayLatitude!, longitude: displayLongitude!) : nil,
                    annotationTitle: isPending ? "\(mountain.name) (Proposed)" : mountain.name,
                    isInteractivePicker: false,
                    isDraggableAnnotation: authViewModel.isAdmin,
                    onAnnotationDrag: { newCoord in
                        withAnimation(.spring()) {
                            adjustedCoordinate = newCoord
                        }
                    },
                    cameraTrigger: cameraTrigger
                )
                .edgesIgnoringSafeArea(.all)
                
                // Admin Help Prompt at Top
                if authViewModel.isAdmin && adjustedCoordinate == nil {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap.fill")
                            .foregroundColor(.orange)
                        Text("Admin Mode: Hold & drag pin or long-press map to adjust")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    .padding(.top, 12)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .transition(.opacity)
                }
                
                // Admin Action Card when coordinate is moved
                if let newCoord = adjustedCoordinate, authViewModel.isAdmin {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundColor(.orange)
                            Text("Admin Mode: Location Adjusted")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Spacer()
                            Button("Reset") {
                                withAnimation(.spring()) {
                                    adjustedCoordinate = nil
                                }
                            }
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        }
                        
                        Text("New GPS: \(String(format: "%.5f, %.5f", newCoord.latitude, newCoord.longitude))")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack(spacing: 10) {
                            if isPending {
                                Button {
                                    saveAdjustedProposal(lat: newCoord.latitude, lon: newCoord.longitude, approveNow: false)
                                } label: {
                                    Text("Update Proposal")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.orange)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                                .disabled(isSaving)
                                
                                Button {
                                    saveAdjustedProposal(lat: newCoord.latitude, lon: newCoord.longitude, approveNow: true)
                                } label: {
                                    Text("Approve Now")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.gliderBlue)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                                .disabled(isSaving)
                            } else {
                                Button {
                                    saveAdjustedOfficialGPS(lat: newCoord.latitude, lon: newCoord.longitude)
                                } label: {
                                    Text("Save Adjusted Official GPS")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.gliderBlue)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                                .disabled(isSaving)
                            }
                        }
                    }
                    .padding(16)
                    .background(.thickMaterial)
                    .cornerRadius(18)
                    .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 5)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 72)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Bottom elevation and coordinates pill
                HStack(spacing: 8) {
                    Image(systemName: "triangle.tophalf.filled")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(isPending ? .orange : .gliderBlue)
                    Text("\(mountain.elevationMASL) MASL")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    if let lat = displayLatitude, let lon = displayLongitude {
                        Text(String(format: "%.4f, %.4f%@", lat, lon, isPending ? " (Proposed)" : ""))
                            .font(.footnote)
                            .foregroundColor(isPending ? .orange : .secondary)
                    } else {
                        Text("Coordinates needed")
                            .font(.footnote)
                            .italic()
                            .foregroundColor(.orange)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                .padding(.bottom, 24)
            }
            .navigationTitle(isPending ? "\(mountain.name) (Proposed)" : mountain.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.gliderBlue)
                    .fontWeight(.semibold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if let lat = displayLatitude, let lon = displayLongitude {
                        Button {
                            center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                            distance = 5000
                            cameraTrigger = UUID()
                        } label: {
                            Image(systemName: "location.north.circle.fill")
                                .font(.title3)
                                .foregroundColor(.gliderBlue)
                        }
                    }
                }
            }
        }
    }
    
    private func saveAdjustedProposal(lat: Double, lon: Double, approveNow: Bool) {
        isSaving = true
        defer { isSaving = false }
        
        if approveNow {
            let newRegion = mountain.pendingRegion ?? mountain.region
            mountain.latitude = lat
            mountain.longitude = lon
            mountain.region = newRegion
            mountain.isVerifiedByCommunity = true
            mountain.communityVerifications += (1 + mountain.pendingVerifications)
            mountain.pendingLatitude = nil
            mountain.pendingLongitude = nil
            mountain.pendingRegion = nil
            mountain.pendingContributorEmail = nil
            mountain.pendingContributorName = nil
            mountain.pendingVerifications = 0
            mountain.pendingVerifierEmails = []
            mountain.updatedAt = Date()
        } else {
            mountain.pendingLatitude = lat
            mountain.pendingLongitude = lon
            mountain.updatedAt = Date()
        }
        
        let db = Firestore.firestore()
        try? db.collection("mountains").document(mountain.id).setData(from: mountain)
        try? modelContext.save()
        MountainsViewModel.shared?.objectWillChange.send()
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        dismiss()
    }
    
    private func saveAdjustedOfficialGPS(lat: Double, lon: Double) {
        isSaving = true
        defer { isSaving = false }
        
        mountain.latitude = lat
        mountain.longitude = lon
        mountain.updatedAt = Date()
        
        let db = Firestore.firestore()
        try? db.collection("mountains").document(mountain.id).setData(from: mountain)
        try? modelContext.save()
        MountainsViewModel.shared?.objectWillChange.send()
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        withAnimation {
            adjustedCoordinate = nil
        }
    }
}
