//
//  SkeletonMountainCardView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 8/5/26.
//

import SwiftUI

/// A reusable shimmering skeleton card view displayed whenever lists or catalogs are initially empty during downloading and Delta-Syncs.
struct SkeletonMountainCardView: View {
    var body: some View {
        HStack(spacing: 16) {
            // Placeholder for Island Group / Mountain Badge Icon
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.gray.opacity(0.35))
                .frame(width: 58, height: 58)
            
            // Placeholder for Mountain Name & Location Subtitle
            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.gray.opacity(0.40))
                    .frame(width: 180, height: 18)
                
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.gray.opacity(0.30))
                        .frame(width: 100, height: 13)
                    
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.gray.opacity(0.25))
                        .frame(width: 50, height: 13)
                }
            }
            
            Spacer()
            
            // Placeholder for Elevation MASL Badge
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.gray.opacity(0.35))
                .frame(width: 72, height: 38)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .modifier(ReusableSkeletonShimmer())
    }
}

/// A traveling light wave modifier creating a dynamic, state-of-the-art shimmer effect across placeholder geometries.
struct ReusableSkeletonShimmer: ViewModifier {
    @State private var phase: CGFloat = -1.0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.white.opacity(0.75),
                            Color.clear
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (phase * geometry.size.width * 2))
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
    }
}

#Preview {
    VStack(spacing: 12) {
        SkeletonMountainCardView()
        SkeletonMountainCardView()
        SkeletonMountainCardView()
    }
    .padding()
}
