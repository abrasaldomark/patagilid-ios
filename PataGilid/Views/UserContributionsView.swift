//
//  UserContributionsView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 8/9/26.
//

import SwiftUI
import FirebaseFirestore

struct UserContributionsView: View {
    @EnvironmentObject var mountainsViewModel: MountainsViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        Group {
            if let email = authViewModel.currentUser?.email {
                let pendingMountains = mountainsViewModel.userPendingMountains(forEmail: email)
                let pendingGPS = mountainsViewModel.userPendingGPS(forEmail: email)
                let approvedMountains = mountainsViewModel.userApprovedMountains(forEmail: email)
                
                if pendingMountains.isEmpty && pendingGPS.isEmpty && approvedMountains.isEmpty {
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
                                    contributionCard(for: peak, status: "Pending", statusColor: .orange)
                                        .padding(.vertical, 4)
                                }
                            }
                        }
                        
                        if !pendingGPS.isEmpty {
                            Section(header: Text("Pending GPS Calibrations (\(pendingGPS.count))")) {
                                ForEach(pendingGPS) { mountain in
                                    contributionCard(for: mountain, status: "Pending", statusColor: .orange)
                                        .padding(.vertical, 4)
                                }
                            }
                        }
                        
                        if !approvedMountains.isEmpty {
                            Section(header: Text("Approved Contributions (\(approvedMountains.count))")) {
                                ForEach(approvedMountains) { peak in
                                    contributionCard(for: peak, status: "Approved", statusColor: .green)
                                        .padding(.vertical, 4)
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
                    
                    Text("📍 \(peak.region)")
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
}
