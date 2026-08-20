//
//  UserContributionsView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 8/9/26.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct UserContributionsView: View {
    @EnvironmentObject var mountainsViewModel: MountainsViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var userGpsSubmissions: [CoordinateSubmission] = []
    
    @State private var editingMountain: Mountain? = nil
    
    @State private var editingGPS: CoordinateSubmission? = nil
    
    private func refreshGps(email: String) {
        let db = Firestore.firestore()
        Task {
            do {
                let snapshot = try await db.collection("coordinate_submissions")
                    .whereField("contributorEmail", isEqualTo: email)
                    .getDocuments()
                let subs = snapshot.documents.compactMap { doc -> CoordinateSubmission? in
                    if let sub = try? doc.data(as: CoordinateSubmission.self) {
                        sub.id = doc.documentID
                        return sub
                    }
                    return nil
                }
                await MainActor.run {
                    userGpsSubmissions = subs.sorted(by: { $0.displayDate > $1.displayDate })
                }
            } catch {
                print("Error fetching user GPS submissions: \(error)")
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
            if let email = authViewModel.currentUser?.email {
                let pendingMountains = mountainsViewModel.userPendingMountains(forEmail: email)
                let approvedMountains = mountainsViewModel.userApprovedMountains(forEmail: email)
                
                if pendingMountains.isEmpty && userGpsSubmissions.isEmpty && approvedMountains.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No Contributions Yet")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("When you submit new mountains or calibrate GPS coordinates, they will appear here.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
                    List {
                        if !pendingMountains.isEmpty {
                            Section(header: Text("Pending Mountains (\(pendingMountains.count))")) {
                                ForEach(pendingMountains) { peak in
                                    NavigationLink(destination: MountainDetailView(mountain: peak)) {
                                        contributionCard(for: peak, status: "Pending", statusColor: .orange)
                                    }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                Task {
                                                    try? await mountainsViewModel.deleteMountain(mountainId: peak.id)
                                                }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                        
                        if !userGpsSubmissions.isEmpty {
                            Section(header: Text("GPS Calibrations (\(userGpsSubmissions.count))")) {
                                ForEach(userGpsSubmissions) { submission in
                                    let statusStr = submission.status.rawValue.capitalized
                                    let color: Color = {
                                        switch submission.status {
                                        case .pending: return .orange
                                        case .approved: return .green
                                        case .rejected, .duplicate: return .red
                                        }
                                    }()
                                    NavigationLink(destination: PendingGpsDetailView(submissionId: submission.id ?? "")) {
                                        gpsContributionCard(for: submission, status: statusStr, statusColor: color)
                                    }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            if submission.status == .pending {
                                                Button(role: .destructive) {
                                                    Task {
                                                        try? await mountainsViewModel.deleteGPSCalibration(submissionId: submission.id ?? "")
                                                        if let email = authViewModel.currentUser?.email {
                                                            refreshGps(email: email)
                                                        }
                                                    }
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                        }
                                }
                            }
                        }
                        
                        if !approvedMountains.isEmpty {
                            Section(header: Text("Approved Contributions (\(approvedMountains.count))")) {
                                ForEach(approvedMountains) { peak in
                                    NavigationLink(destination: MountainDetailView(mountain: peak)) {
                                        contributionCard(for: peak, status: "Approved", statusColor: .green)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            } else {
                Text("Please sign in to view your contributions.")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("My Contributions")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: authViewModel.currentUser?.email) {
            if let email = authViewModel.currentUser?.email {
                refreshGps(email: email)
            }
        }
        }
    }
    
    @ViewBuilder
    private func contributionCard(for peak: Mountain, status: String, statusColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(peak.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("📍 \\(peak.region)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                Text(status)
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.15))
                    .foregroundColor(statusColor)
                    .cornerRadius(6)
            }
            
            Text(peak.descriptionText)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
    }
    
    @ViewBuilder
    private func gpsContributionCard(for submission: CoordinateSubmission, status: String, statusColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(submission.mountainName ?? "GPS Calibration (\(submission.region ?? "Unknown"))")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("📍 GPS Calibration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                Text(status)
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.15))
                    .foregroundColor(statusColor)
                    .cornerRadius(6)
            }
            
            Text(String(format: "%.6f, %.6f", submission.latitude, submission.longitude))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

import CoreLocation

struct GPSCalibrationEditWrapper: View {
    let gps: CoordinateSubmission
    @Binding var isPresented: Bool
    var onSave: (CLLocationCoordinate2D, String?) -> Void
    
    @State private var tempCoordinate: CLLocationCoordinate2D?
    @State private var tempPlaceName: String?
    
    var body: some View {
        NavigationView {
            CoordinateSelectionView(
                selectedCoordinate: $tempCoordinate,
                selectedPlaceName: $tempPlaceName,
                onConfirm: { newCoord in
                    onSave(newCoord, tempPlaceName)
                    isPresented = false
                }
            )
            .onAppear {
                tempCoordinate = CLLocationCoordinate2D(latitude: gps.latitude, longitude: gps.longitude)
            }
            .navigationTitle("Edit GPS Calibration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
