//
//  ProPaywallView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/28/26.
//

import SwiftUI

/// Promotional one-time upgrade paywall for PataGilid Pro.
struct ProPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isPataGilidPro") private var isProUser: Bool = false
    @State private var isProcessing: Bool = false
    @State private var showSuccessAlert: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Hero Icon & Badge
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.orange.opacity(0.25), .red.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 110, height: 110)
                            
                            Image(systemName: "mountain.2.fill")
                                .font(.system(size: 52, weight: .black))
                                .foregroundStyle(
                                    LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        
                        VStack(spacing: 6) {
                            Text("Upgrade to PataGilid Pro")
                                .font(.title)
                                .fontWeight(.black)
                                .multilineTextAlignment(.center)
                            
                            Text("One-time payment for lifetime mountaineering access.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                    }
                    .padding(.top, 16)
                    
                    // Feature List
                    VStack(spacing: 20) {
                        featureRow(
                            icon: "photo.stack.fill",
                            color: .orange,
                            title: "Climb Photo Memories",
                            subtitle: "Attach up to 3 jump-off and summit photos directly to your ascent logs."
                        )
                        
                        featureRow(
                            icon: "cloud.fill",
                            color: .teal,
                            title: "Cloud Backup & Sync",
                            subtitle: "Safely sync your climb records across all your iOS devices without losing history."
                        )
                        
                        featureRow(
                            icon: "figure.hiking",
                            color: .emeraldGreen,
                            title: "Support Philippine Trails",
                            subtitle: "Help fund ongoing curation of Philippine peak data, elevations, and GPS trail info."
                        )
                    }
                    .padding(20)
                    .background(Color.secondary.opacity(0.06))
                    .cornerRadius(20)
                    .padding(.horizontal)
                    
                    // Purchase Call to Action
                    VStack(spacing: 14) {
                        Button {
                            purchasePro()
                        } label: {
                            HStack(spacing: 10) {
                                if isProcessing {
                                    ProgressView().tint(.white)
                                    Text("Processing Upgrade...")
                                } else {
                                    Image(systemName: "crown.fill")
                                    Text("Unlock Lifetime Pro — ₱249")
                                }
                            }
                            .font(.headline)
                            .fontWeight(.heavy)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                LinearGradient(
                                    colors: [.orange, .red.opacity(0.9)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: .orange.opacity(0.35), radius: 10, x: 0, y: 5)
                        }
                        .disabled(isProcessing)
                        
                        Text("No subscriptions. No recurring fees. Yours forever.")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        // Developer Testing Helper (Easily toggle status during development)
                        Button {
                            isProUser.toggle()
                            dismiss()
                        } label: {
                            Text(isProUser ? "[Dev Tool] Relock Pro Feature" : "[Dev Tool] Instant Unlock (Skip Demo)")
                                .font(.caption2)
                                .underline()
                                .foregroundColor(.gray.opacity(0.7))
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .alert("Welcome to PataGilid Pro! 🏔️👑", isPresented: $showSuccessAlert) {
                Button("Let's Climb!") {
                    dismiss()
                }
            } message: {
                Text("Your lifetime access is unlocked. You can now attach climb photos to all your summit logs!")
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func featureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
    
    // MARK: - Actions
    
    private func purchasePro() {
        isProcessing = true
        // Simulate App Store in-app purchase delay for demo/testing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isProcessing = false
            isProUser = true
            showSuccessAlert = true
        }
    }
}

#Preview {
    ProPaywallView()
}
