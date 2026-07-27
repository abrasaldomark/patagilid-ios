//
//  ContentView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/27/26.
//

import SwiftUI

/// The primary application entry view that directs the mountaineer to Google Sign-In or the main dashboard.
struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    
    var body: some View {
        Group {
            if !hasSeenOnboarding {
                OnboardingView()
                    .transition(.opacity)
            } else if authViewModel.isLoggedIn {
                MainTabView(authViewModel: authViewModel)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                LoginView(authViewModel: authViewModel)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: authViewModel.isLoggedIn)
        .animation(.easeInOut(duration: 0.35), value: hasSeenOnboarding)
    }
}

#Preview {
    ContentView()
}
