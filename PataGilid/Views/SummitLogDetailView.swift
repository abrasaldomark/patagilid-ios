//
//  SummitLogDetailView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/28/26.
//

import SwiftUI

/// Full detail screen for a single recorded climb attempt.
struct SummitLogDetailView: View {
    let log: HikeLog
    let mountain: Mountain?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                outcomeHero
                detailCards
                if !log.photoUrls.isEmpty {
                    photosCard
                }
                Spacer(minLength: 20)
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(mountain?.name ?? "Climb Log")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Outcome Hero Banner
    
    private var outcomeHero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(log.didSummit ? Color.emeraldGreen.opacity(0.12) : Color.red.opacity(0.10))
                    .frame(width: 80, height: 80)
                Image(systemName: log.didSummit ? "mountain.2.fill" : "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(log.didSummit ? .emeraldGreen : .red)
            }
            
            Text(log.didSummit ? "Summited" : "Turned Back")
                .font(.title2)
                .fontWeight(.black)
                .foregroundColor(log.didSummit ? .emeraldGreen : .red)
            
            Text(log.dateTimeStart.formatted(date: .complete, time: .shortened))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(18)
    }
    
    // MARK: - Detail Cards
    
    private var detailCards: some View {
        VStack(spacing: 14) {
            // Mountain Info Section
            if let mountain {
                sectionCard(title: "Summit Details") {
                    detailRow(icon: "mountain.2.fill", iconColor: .emeraldGreen,
                              label: "Mountain", value: mountain.name)
                    Divider().padding(.leading, 40)
                    detailRow(icon: "location.fill", iconColor: .teal,
                              label: "Elevation", value: "\(mountain.elevationMASL) MASL")
                    Divider().padding(.leading, 40)
                    detailRow(icon: "mappin.circle.fill", iconColor: .red,
                              label: "Region", value: mountain.region)
                    Divider().padding(.leading, 40)
                    detailRow(icon: "globe.asia.australia.fill", iconColor: .blue,
                              label: "Island Group", value: mountain.islandGroup.rawValue)
                    Divider().padding(.leading, 40)
                    detailRow(icon: "gauge.medium", iconColor: .orange,
                              label: "Difficulty", value: mountain.difficultyLevel)
                    Divider().padding(.leading, 40)
                    detailRow(icon: "figure.hiking", iconColor: .green,
                              label: "Trail Class", value: mountain.trailClass)
                }
            }
            
            // Climb Attempt Section
            sectionCard(title: "Attempt Record") {
                detailRow(icon: "play.circle.fill", iconColor: .emeraldGreen,
                          label: "Start", value: log.dateTimeStart.formatted(date: .abbreviated, time: .shortened))
                Divider().padding(.leading, 40)
                detailRow(icon: "stop.circle.fill", iconColor: .red,
                          label: "End", value: log.dateTimeEnd.formatted(date: .abbreviated, time: .shortened))
                Divider().padding(.leading, 40)
                detailRow(icon: "timer", iconColor: .purple,
                          label: "Duration", value: duration(from: log.dateTimeStart, to: log.dateTimeEnd))
                Divider().padding(.leading, 40)
                detailRow(
                    icon: log.didSummit ? "checkmark.circle.fill" : "xmark.circle.fill",
                    iconColor: log.didSummit ? .emeraldGreen : .red,
                    label: "Outcome",
                    value: log.didSummit ? "Successful Summit" : "Turned Back"
                )
            }
        }
    }
    
    // MARK: - Photos Card
    
    private var photosCard: some View {
        sectionCard(title: "Climb Photos (\(log.photoUrls.count))") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(log.photoUrls, id: \.self) { urlString in
                        AsyncImage(url: URL(string: urlString)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(width: 160, height: 160)
                                    .background(Color.secondary.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 160, height: 160)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            case .failure:
                                VStack(spacing: 6) {
                                    Image(systemName: "photo.fill")
                                        .foregroundColor(.secondary)
                                    Text("Failed to load")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .frame(width: 160, height: 160)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    // MARK: - Duration Helper
    
    private func duration(from start: Date, to end: Date) -> String {
        let components = Calendar.current.dateComponents([.day, .hour, .minute], from: start, to: end)
        var parts: [String] = []
        if let d = components.day, d > 0 { parts.append("\(d)d") }
        if let h = components.hour, h > 0 { parts.append("\(h)h") }
        if let m = components.minute, m > 0 { parts.append("\(m)m") }
        return parts.isEmpty ? "< 1 min" : parts.joined(separator: " ")
    }
    
    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
                .padding(.horizontal)
                .padding(.bottom, 8)
            
            VStack(spacing: 0) {
                content()
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(14)
        }
    }
    
    private func detailRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 28)
            
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

#Preview {
    NavigationStack {
        SummitLogDetailView(
            log: HikeLog(
                userId: "preview",
                mountainId: "preview",
                dateTimeStart: Date(),
                dateTimeEnd: Calendar.current.date(byAdding: .hour, value: 8, to: Date()) ?? Date(),
                didSummit: true,
                photoUrls: []
            ),
            mountain: Mountain(
                id: "preview",
                name: "Mt. Apo",
                description: "Highest peak in the Philippines.",
                elevationMASL: 2954,
                latitude: 6.98,
                longitude: 125.27,
                region: "Region 11 (Davao Region)",
                islandGroup: .mindanao,
                difficultyLevel: "7/9",
                trailClass: "Class 2-4"
            )
        )
    }
}
