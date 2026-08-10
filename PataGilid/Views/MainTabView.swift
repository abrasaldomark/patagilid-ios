//
//  MainTabView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/27/26.
//

import SwiftUI
import SwiftData
import FirebaseAuth

/// The main dashboard application screen after a user logs in via Google Sign-In.
struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var mountainsViewModel = MountainsViewModel()
    @State private var showAdminQueue: Bool = false
    @State private var showDonationSheet: Bool = false
    @State private var showMyContributions: Bool = false
    @State private var showSponsors: Bool = false
    @State private var selectedTab: Int = 0
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = true
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Mountain List Explorer
            MountainsListView()
                .tabItem {
                    Label("Mountains", systemImage: "mountain.2.fill")
                }
                .tag(0)
                .task {
                    await mountainsViewModel.synchronize(in: modelContext)
                }

            
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
                        Section(header: Text("Administrator Control Center"), footer: Text("As a verified PataGilid administrator, you can moderate, approve, or merge crowdsourced local mountains before they appear on the nationwide public list.")) {
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
                                        .foregroundColor(.summitSteel)
                                    Text("Open Moderation Queue")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if !mountainsViewModel.hasPendingReviews {
                                        Text("0 Pending")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("\(mountainsViewModel.totalPendingReviewsCount)")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .frame(width: 24, height: 24)
                                            .background(Color.red)
                                            .foregroundColor(.white)
                                            .clipShape(Circle())
                                    }
                                }
                            }
                        }
                    }
                    Section(
                        header: Text("Support the Developer"),
                        footer: Text("PataGilid is free to use. If it has helped your mountaineering journeys, a small coffee goes a long way! ☕️")
                    ) {
                        Button {
                            showDonationSheet = true
                        } label: {
                            HStack(spacing: 14) {
                                Text("⛰️")
                                    .font(.system(size: 26))
                                    .frame(width: 44, height: 44)
                                    .background(Color.yellow.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Pang akyat lang")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Text("Scan my bank QR and fuel the dev's next summit attempt 🥾🏕️⛰️")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "qrcode")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        Button {
                            showSponsors = true
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "heart.circle.fill")
                                    .font(.system(size: 26))
                                    .frame(width: 44, height: 44)
                                    .foregroundColor(.gliderBlue)
                                    .background(Color.gliderBlue.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Donators & Sponsors")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Text("See the organizations and hikers who make PataGilid possible.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Section(header: Text("Account Settings")) {
                        Button {
                            showMyContributions = true
                        } label: {
                            HStack {
                                Image(systemName: "list.bullet.rectangle.portrait")
                                    .foregroundColor(.gliderBlue)
                                Text("My Contributions")
                                    .foregroundColor(.primary)
                            }
                        }
                        
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
                .sheet(isPresented: $showMyContributions) {
                    UserContributionsView()
                        .environmentObject(mountainsViewModel)
                        .environmentObject(authViewModel)
                }
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle.fill")
            }
            .tag(2)
        }
        .tint(.gliderBlue)
        .environmentObject(authViewModel)
        .environmentObject(mountainsViewModel)
        .sheet(isPresented: $showAdminQueue) {
            AdminModerationQueueView()
                .environmentObject(mountainsViewModel)
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showDonationSheet) {
            DonationQRView()
        }
        .sheet(isPresented: $showSponsors) {
            SponsorsView()
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
