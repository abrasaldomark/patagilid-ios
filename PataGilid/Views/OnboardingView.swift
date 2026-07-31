//
//  OnboardingView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/28/26.
//

import SwiftUI

/// Data model representing a single step in the 4-view mountaineer onboarding tour.
struct OnboardingPage: Identifiable {
    let id = UUID()
    let systemImage: String
    let iconTint: Color
    let badgeText: String?
    let title: String
    let subtitle: String
}

/// An interactive 4-step onboarding journey designed to educate hikers about peak curation, filtering, climb journaling, and pro features.
struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @State private var currentPage: Int = 0
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            systemImage: "mountain.2.circle.fill",
            iconTint: .gliderBlue,
            badgeText: "EXPLORE",
            title: "Discover Philippine Peaks",
            subtitle: "Explore over 2,300 official mountains across Luzon, Visayas, and Mindanao with precise elevations and trail difficulty ratings."
        ),
        OnboardingPage(
            systemImage: "line.3.horizontal.decrease.circle.fill",
            iconTint: .summitSteel,
            badgeText: "CURATE",
            title: "Filter & Plan Ascents",
            subtitle: "Effortlessly sort peaks by elevation or filter by island groups and provinces to curate your personal hiking bucket list."
        ),
        OnboardingPage(
            systemImage: "figure.hiking",
            iconTint: .orange,
            badgeText: "JOURNAL",
            title: "Log Your Climb Legacies",
            subtitle: "Record your summit triumphs with timestamps, duration times, and personal trail notes whether online or deep in the wilderness."
        ),
        OnboardingPage(
            systemImage: "camera.fill.badge.ellipsis",
            iconTint: .orange,
            badgeText: nil,
            title: "Preserve Climb Memories",
            subtitle: "Attach high-definition photos to any climb log and back up your entire climbing legacy securely to your Google Drive — free for every hiker."
        )
    ]
    
    var body: some View {
        ZStack {
            // Background gradient
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header: Skip button
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                hasSeenOnboarding = true
                            }
                        } label: {
                            Text("Skip")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.secondary.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .transition(.opacity)
                    } else {
                        Spacer().frame(height: 36)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Pages Swiper
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        pageCard(for: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)
                
                // Footer Controls: Custom Dots & Buttons
                footerControls
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
        }
    }
    
    // MARK: - Page View
    
    private func pageCard(for page: OnboardingPage) -> some View {
        VStack(spacing: 24) {
            Spacer(minLength: 10)
            
            // Icon emblem with circular shadow
            ZStack {
                Circle()
                    .fill(page.iconTint.opacity(0.12))
                    .frame(width: 144, height: 144)
                
                Circle()
                    .fill(page.iconTint.opacity(0.25))
                    .frame(width: 116, height: 116)
                
                Image(systemName: page.systemImage)
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(page.iconTint)
                    .shadow(color: page.iconTint.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.top, 10)
            
            // Text copy
            VStack(spacing: 12) {
                if let badge = page.badgeText {
                    Text(badge)
                        .font(.caption2)
                        .fontWeight(.black)
                        .tracking(1.2)
                        .foregroundColor(page.iconTint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(page.iconTint.opacity(0.15))
                        .clipShape(Capsule())
                }
                
                Text(page.title)
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .minimumScaleFactor(0.75)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(page.subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }
            
            Spacer(minLength: 20)
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Footer Controls
    
    private var footerControls: some View {
        VStack(spacing: 24) {
            // Custom dot pagination indicator
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Capsule()
                        .fill(currentPage == index ? pages[index].iconTint : Color.secondary.opacity(0.25))
                        .frame(width: currentPage == index ? 28 : 8, height: 8)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: currentPage)
                }
            }
            
            // Action buttons with uniform height and full-width styling
            if currentPage == pages.count - 1 {
                Button {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        hasSeenOnboarding = true
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text("Start Exploring Peaks")
                            .font(.headline)
                            .fontWeight(.bold)
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title3)
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
                    .shadow(color: Color.gliderBlue.opacity(0.35), radius: 8, x: 0, y: 4)
                }
                .transition(.opacity)
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentPage += 1
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text("Next")
                            .font(.headline)
                            .fontWeight(.bold)
                        Image(systemName: "arrow.right")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 54, maxHeight: 54)
                    .background(pages[currentPage].iconTint)
                    .cornerRadius(16)
                    .shadow(color: pages[currentPage].iconTint.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .transition(.opacity)
            }
        }
    }
}

#Preview {
    OnboardingView()
}
