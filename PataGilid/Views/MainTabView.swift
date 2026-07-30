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
    @StateObject private var peaksViewModel = PeaksViewModel()
    @State private var showAdminQueue: Bool = false
    @State private var selectedTab: Int = 0
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = true
    
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
                                CachedAsyncImage(url: photoURL) { phase in
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
                    
                    if authViewModel.isAdmin {
                        Section(header: Text("Administrator Control Center"), footer: Text("As a verified PataGilid administrator, you can moderate, approve, or merge crowdsourced local mountains before they appear in the nationwide public catalog.")) {
                            HStack {
                                Image(systemName: "shield.checkmark.fill")
                                    .foregroundColor(.summitSteel)
                                    .font(.title2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Super Admin Mode Active")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                    Text(authViewModel.currentUser?.email ?? "Verified Administrator")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 2)
                            
                            Button(action: { showAdminQueue = true }) {
                                HStack {
                                    Image(systemName: "checklist.checked")
                                        .foregroundColor(.orange)
                                    Text("Open Moderation Queue")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if peaksViewModel.pendingReviewPeaks.isEmpty {
                                        Text("0 Pending")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("\(peaksViewModel.pendingReviewPeaks.count)")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.orange)
                                            .foregroundColor(.white)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                    Section(header: Text("Account Settings")) {
                        Button {
                            hasSeenOnboarding = false
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.orange)
                                Text("Replay Onboarding Tour")
                                    .foregroundColor(.primary)
                            }
                        }
                        
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
        .tint(.gliderBlue)
        .environmentObject(authViewModel)
        .environmentObject(peaksViewModel)
        .sheet(isPresented: $showAdminQueue) {
            AdminModerationQueueView()
                .environmentObject(peaksViewModel)
        }
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
