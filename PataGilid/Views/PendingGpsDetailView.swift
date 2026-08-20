//
//  PendingGpsDetailView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 8/19/26.
//

import SwiftUI
import MapKit
import FirebaseFirestore
import FirebaseAuth

struct PendingGpsDetailView: View {
    let submissionId: String
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var mountainsViewModel: MountainsViewModel
    
    @State private var submission: CoordinateSubmission? = nil
    @State private var isLoading: Bool = true
    @State private var showingEditModal: Bool = false
    
    private func fetchSubmission() {
        let db = Firestore.firestore()
        Task {
            do {
                let doc = try await db.collection("coordinate_submissions").document(submissionId).getDocument()
                if let sub = try? doc.data(as: CoordinateSubmission.self) {
                    sub.id = doc.documentID
                    await MainActor.run {
                        self.submission = sub
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run { self.isLoading = false }
                }
            } catch {
                print("Error fetching submission: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading GPS Calibration...")
            } else if let sub = submission {
                VStack(spacing: 0) {
                    GoogleMapView(
                        centerCoordinate: CLLocationCoordinate2D(latitude: sub.latitude, longitude: sub.longitude),
                        distance: 5000,
                        annotationCoordinate: CLLocationCoordinate2D(latitude: sub.latitude, longitude: sub.longitude),
                        annotationTitle: "Submitted Location",
                        isInteractivePicker: false,
                        isDraggableAnnotation: false,
                        onAnnotationDrag: nil,
                        cameraTrigger: UUID()
                    )
                    .frame(maxHeight: .infinity)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Region")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                            Text(sub.region ?? "Unknown Region")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Coordinates")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.6f, %.6f", sub.latitude, sub.longitude))
                                .font(.body)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Status")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                            
                            let statusColor: Color = {
                                switch sub.status {
                                case .pending: return .orange
                                case .approved: return .green
                                case .rejected, .duplicate: return .red
                                }
                            }()
                            
                            Text(sub.status.rawValue.capitalized)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(statusColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(statusColor.opacity(0.15))
                                .cornerRadius(8)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
                }
            } else {
                Text("Calibration not found.")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("GPS Calibration")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if let sub = submission, sub.status == .pending, let email = authViewModel.currentUser?.email, sub.contributorEmail == email {
                    Button {
                        showingEditModal = true
                    } label: {
                        Text("Edit")
                            .fontWeight(.semibold)
                            .foregroundColor(.gliderBlue)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingEditModal) {
            if let sub = submission {
                GPSCalibrationEditWrapper(
                    gps: sub,
                    isPresented: $showingEditModal,
                    onSave: { newCoord, newRegion in
                        isLoading = true
                        Task {
                            try? await mountainsViewModel.updateGPSCalibration(
                                submissionId: submissionId,
                                lat: newCoord.latitude,
                                lon: newCoord.longitude,
                                region: newRegion
                            )
                            fetchSubmission()
                        }
                    }
                )
            }
        }
        .onAppear {
            fetchSubmission()
        }
    }
}