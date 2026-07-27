//
//  MainTabView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/27/26.
//

import SwiftUI
import FirebaseAuth

/// The main dashboard application screen after a user logs in via Google Sign-In.
struct MainTabView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var selectedTab: Int = 0
    @State private var isSeeding: Bool = false
    @State private var seedMessage: String?
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Peak Catalog Explorer
            PeaksListView()
                .tabItem {
                    Label("Peaks", systemImage: "mountain.2.fill")
                }
                .tag(0)
            
            // Tab 2: Summit Logs
            SummitLogsView()
                .tabItem {
                    Label("My Climbs", systemImage: "figure.hiking")
                }
                .tag(1)
            
            // Tab 3: Profile & Admin Utilities
            NavigationStack {
                List {
                    Section(header: Text("Mountaineer Profile")) {
                        HStack(spacing: 16) {
                            if let photoURL = authViewModel.userPhotoURL {
                                AsyncImage(url: photoURL) { phase in
                                    if let image = phase.image {
                                        image.resizable()
                                             .aspectRatio(contentMode: .fill)
                                             .frame(width: 54, height: 54)
                                             .clipShape(Circle())
                                    } else if phase.error != nil {
                                        fallbackAvatar
                                    } else {
                                        ProgressView()
                                            .frame(width: 54, height: 54)
                                    }
                                }
                            } else {
                                fallbackAvatar
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(authViewModel.userDisplayName)
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Text(authViewModel.currentUser?.email ?? "Verified Google Account")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Section(header: Text("Database Synchronization")) {
                        Button(action: {
                            Task {
                                isSeeding = true
                                seedMessage = "Synchronizing 2,313 mountains to Firestore in batches..."
                                do {
                                    try await MountainDataSeeder.shared.seedMountainsIfNeeded()
                                    seedMessage = "✅ All 2,313 mountains successfully synchronized!"
                                } catch {
                                    seedMessage = "❌ Sync failed: \(error.localizedDescription)"
                                }
                                isSeeding = false
                            }
                        }) {
                            HStack {
                                Image(systemName: "cloud.upload.fill")
                                    .foregroundColor(.teal)
                                Text(isSeeding ? "Syncing to Firestore..." : "Seed 2,313 Peaks to Firestore")
                                    .foregroundColor(.primary)
                                Spacer()
                                if isSeeding {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isSeeding)
                        
                        if let seedMessage = seedMessage {
                            Text(seedMessage)
                                .font(.caption)
                                .foregroundColor(.teal)
                        }
                    }
                    
                    Section(header: Text("Account Settings")) {
                        Button(role: .destructive, action: {
                            authViewModel.signOut()
                        }) {
                            HStack {
                                Image(systemName: "arrow.right.square.fill")
                                Text("Sign Out of Google Account")
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
                .navigationTitle("Profile & Settings")
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle.fill")
            }
            .tag(2)
        }
        .tint(.teal)
    }
    
    private var fallbackAvatar: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 54, height: 54)
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(.gray)
            )
    }
}

#Preview {
    MainTabView(authViewModel: AuthViewModel())
}
