//
//  LoginView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/27/26.
//

import SwiftUI

/// A premium, immersive login interface emphasizing the requirement for a Google Account to secure hiking progress.
struct LoginView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    var body: some View {
        ZStack {
            // Clean dynamic background consistent with Onboarding & Main App Views
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            // Subtle theme decorative accent gradient at the top
            VStack {
                RadialGradient(
                    gradient: Gradient(colors: [Color.gliderBlue.opacity(0.25), Color.clear]),
                    center: .top,
                    startRadius: 20,
                    endRadius: 320
                )
                .frame(height: 380)
                .ignoresSafeArea()
                Spacer()
            }
            
            VStack(spacing: 36) {
                Spacer()
                
                // Branding & Icon
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.gliderBlue.opacity(0.12))
                            .frame(width: 120, height: 120)
                        
                        Circle()
                            .stroke(Color.gliderBlue.opacity(0.3), lineWidth: 2)
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "mountain.2.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .foregroundStyle(
                                LinearGradient(colors: [.gliderBlue, .summitSteel], startPoint: .top, endPoint: .bottom)
                            )
                    }
                    .shadow(color: Color.gliderBlue.opacity(0.25), radius: 12, x: 0, y: 6)
                    
                    VStack(spacing: 6) {
                        Text("PataGilid")
                            .font(.system(size: 42, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                            .tracking(1.2)
                        
                        Text("Your Guide to 2,688 Philippine Mountains")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.summitSteel)
                    }
                }
                
                Spacer()
                
                // Account Requirement Banner & Action Box
                VStack(spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(.gliderBlue)
                                .font(.headline)
                            Text("Account Required for Climb Logs")
                                .font(.footnote)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        
                        Text("A verified Google account is required to securely back up your summit progress, photos, and hiking achievements across devices.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(18)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gliderBlue.opacity(0.25), lineWidth: 1.5)
                    )
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 24)
                    
                    // Google Sign-In Action Button
                    Button(action: {
                        authViewModel.signInWithGoogle()
                    }) {
                        HStack(spacing: 12) {
                            if authViewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "g.circle.fill")
                                    .font(.title2)
                            }
                            
                            Text(authViewModel.isLoading ? "Connecting to Google..." : "Continue with Google")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 54, maxHeight: 54)
                        .background(
                            LinearGradient(
                                colors: [.gliderBlue, .summitSteel],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: Color.gliderBlue.opacity(0.35), radius: 10, x: 0, y: 5)
                    }
                    .disabled(authViewModel.isLoading)
                    .padding(.horizontal, 24)
                }
                
                if let errorMessage = authViewModel.errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                }
                
                Spacer().frame(height: 24)
            }
        }
    }
}

// Custom Accent Helper for the Theme
extension Color {
    static let gliderBlue = Color(red: 0.23, green: 0.51, blue: 0.96)
    static let summitSteel = Color(red: 0.58, green: 0.64, blue: 0.72)
}

extension ShapeStyle where Self == Color {
    static var gliderBlue: Color { .gliderBlue }
    static var summitSteel: Color { .summitSteel }
}

#Preview {
    LoginView(authViewModel: AuthViewModel())
}
