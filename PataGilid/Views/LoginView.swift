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
            // Sleek Dark Mountain Gradient Background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.08, green: 0.12, blue: 0.18),
                    Color(red: 0.05, green: 0.07, blue: 0.10),
                    Color.black
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Branding & Icon
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.emeraldGreen.opacity(0.15))
                            .frame(width: 110, height: 110)
                        
                        Image(systemName: "mountain.2.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .foregroundStyle(
                                LinearGradient(colors: [.green, .teal], startPoint: .top, endPoint: .bottom)
                            )
                    }
                    
                    Text("PataGilid")
                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(1.5)
                    
                    Text("Your Guide to 2,313 Philippine Peaks")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Account Requirement Banner & Action Box
                VStack(spacing: 20) {
                    VStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(.teal)
                            Text("Account Required for Climbing Logs")
                                .font(.footnote)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        
                        Text("A verified Google account is required to securely back up your summit progress, photos, and hiking achievements across devices.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.teal.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    
                    // Google Sign-In Action Button
                    Button(action: {
                        authViewModel.signInWithGoogle()
                    }) {
                        HStack(spacing: 12) {
                            if authViewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            } else {
                                Image(systemName: "g.circle.fill")
                                    .font(.title2)
                            }
                            
                            Text(authViewModel.isLoading ? "Connecting to Google..." : "Continue with Google")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .cornerRadius(14)
                        .shadow(color: Color.white.opacity(0.15), radius: 10, x: 0, y: 5)
                    }
                    .disabled(authViewModel.isLoading)
                    .padding(.horizontal, 24)
                }
                
                if let errorMessage = authViewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
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
    static let emeraldGreen = Color(red: 0.16, green: 0.73, blue: 0.53)
}

#Preview {
    LoginView(authViewModel: AuthViewModel())
}
