//
//  SummitLogDetailView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/28/26.
//

import SwiftUI

/// Full detail screen for a single recorded climb attempt.
struct SummitLogDetailView: View {
    @State private var log: HikeLog
    let mountain: Mountain?
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var actionViewModel = HikeLogViewModel()
    @State private var selectedPhotoIndex: Int = 0
    @State private var isShowingPhotoGallery: Bool = false
    @State private var isShowingEditModal: Bool = false
    @State private var isShowingDeleteConfirm: Bool = false
    @State private var showingInternalMap: Bool = false
    
    init(log: HikeLog, mountain: Mountain?) {
        _log = State(initialValue: log)
        self.mountain = mountain
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                outcomeHero
                detailCards
                if !log.cleanPhotoUrls.isEmpty {
                    photosCard
                }
                deleteButton
                Spacer(minLength: 20)
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(mountain?.name ?? "Climb Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    isShowingEditModal = true
                }
                .fontWeight(.semibold)
                .foregroundColor(.gliderBlue)
            }
        }
        .sheet(isPresented: $isShowingEditModal) {
            let targetMountain = mountain ?? Mountain(
                id: log.mountainId,
                name: "Recorded Climb",
                description: "",
                elevationMASL: 0,
                latitude: 0,
                longitude: 0,
                region: "Philippines",
                islandGroup: .luzon,
                difficultyLevel: log.trailDifficulty ?? "Unknown",
                trailClass: log.trailClass ?? "Unknown"
            )
            HikeLogCreationView(mountain: targetMountain, logToEdit: log) { updatedLog in
                self.log = updatedLog
            }
        }
        .sheet(isPresented: $showingInternalMap) {
            if let mountain {
                MountainMapView(mountain: mountain)
                    .environmentObject(authViewModel)
            }
        }
    }
    
    // MARK: - Outcome Hero Banner
    
    private var outcomeHero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(log.didSummit ? Color.gliderBlue.opacity(0.12) : Color.red.opacity(0.10))
                    .frame(width: 80, height: 80)
                Image(systemName: log.didSummit ? "mountain.2.fill" : "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(log.didSummit ? .gliderBlue : .red)
            }
            
            Text(log.didSummit ? "Summited" : "Backed Out")
                .font(.title2)
                .fontWeight(.black)
                .foregroundColor(log.didSummit ? .gliderBlue : .red)
            
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
                    detailRow(icon: "mountain.2.fill", iconColor: .gliderBlue,
                              label: "Mountain", value: mountain.name)
                    Divider().padding(.leading, 40)
                    detailRow(icon: "location.fill", iconColor: .summitSteel,
                              label: "Elevation", value: "\(mountain.elevationMASL) MASL")
                    Divider().padding(.leading, 40)
                    detailRow(icon: "mappin.circle.fill", iconColor: .red,
                              label: "Region", value: mountain.region)
                    Divider().padding(.leading, 40)
                    detailRow(icon: "globe.asia.australia.fill", iconColor: .blue,
                              label: "Island Group", value: mountain.islandGroup.rawValue)
                    Divider().padding(.leading, 40)
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showingInternalMap = true
                    } label: {
                        HStack(spacing: 4) {
                            let coordsText = (mountain.latitude != nil && mountain.longitude != nil) ? String(format: "%.4f, %.4f", mountain.latitude!, mountain.longitude!) : "Coordinates needed"
                            detailRow(icon: "location.circle.fill", iconColor: .gliderBlue,
                                      label: "Coordinates", value: coordsText)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.gliderBlue)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Route & Trail Section
            sectionCard(title: "Route Experienced") {
                if log.routeType == "Traverse" {
                    detailRow(icon: "point.bottomleft.forward.to.point.topright.scurvepath", iconColor: .purple,
                              label: "Climb Style", value: "Traverse Route")
                    Divider().padding(.leading, 40)
                    if !log.trailName.isEmpty {
                        detailRow(icon: "arrow.down.right.circle.fill", iconColor: .summitSteel,
                                  label: "Start Trail", value: log.trailName)
                        Divider().padding(.leading, 40)
                    }
                    if !log.exitTrailName.isEmpty {
                        detailRow(icon: "arrow.up.right.circle.fill", iconColor: .red,
                                  label: "Exit Trail", value: log.exitTrailName)
                        Divider().padding(.leading, 40)
                    }
                } else if log.routeType == "Circuit" {
                    detailRow(icon: "arrow.triangle.2.circlepath", iconColor: .orange,
                              label: "Climb Style", value: "Circuit Route")
                    Divider().padding(.leading, 40)
                    if !log.trailName.isEmpty {
                        detailRow(icon: "arrow.up.and.down.circle.fill", iconColor: .summitSteel,
                                  label: "Start & End Trail", value: log.trailName)
                        Divider().padding(.leading, 40)
                    }
                    if !log.waypoints.isEmpty {
                        detailRow(icon: "mappin.and.ellipse", iconColor: .green,
                                  label: "Waypoints", value: log.waypoints.joined(separator: ", "))
                        Divider().padding(.leading, 40)
                    }
                } else {
                    detailRow(icon: "point.forward.to.point.capsulepath", iconColor: .blue,
                              label: "Climb Style", value: "Back Trail (Same Start & Exit)")
                    Divider().padding(.leading, 40)
                    if !log.trailName.isEmpty {
                        detailRow(icon: "arrow.up.and.down.circle.fill", iconColor: .summitSteel,
                                  label: "Back Trail Name", value: log.trailName)
                        Divider().padding(.leading, 40)
                    }
                }
                
                let trailDiff = log.trailDifficulty.isEmpty ? (mountain?.difficultyLevel ?? "N/A") : log.trailDifficulty
                detailRow(icon: "gauge.with.dots.needle.bottom.100percent", iconColor: .gliderBlue,
                          label: "Experienced Difficulty", value: trailDiff)
                Divider().padding(.leading, 40)
                let trailClassVal = log.trailClass.isEmpty ? (mountain?.trailClass ?? "N/A") : log.trailClass
                detailRow(icon: "figure.climbing", iconColor: .summitSteel,
                          label: "Technical Trail Class", value: trailClassVal)
            }
            
            // Climb Attempt Section
            sectionCard(title: "Attempt Record") {
                detailRow(icon: "play.circle.fill", iconColor: .summitSteel,
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
                    iconColor: log.didSummit ? .gliderBlue : .red,
                    label: "Outcome",
                    value: log.didSummit ? "Successful Summit" : "Backed Out"
                )
            }
        }
    }
    
    // MARK: - Photos Card
    
    private var photosCard: some View {
        sectionCard(title: "Climb Photos (\(log.cleanPhotoUrls.count))") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(log.cleanPhotoUrls.enumerated()), id: \.offset) { index, urlString in
                        Button {
                            selectedPhotoIndex = index
                            isShowingPhotoGallery = true
                        } label: {
                            CachedAsyncImage(url: URL(string: urlString)) { phase in
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
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .fullScreenCover(isPresented: $isShowingPhotoGallery) {
            FullScreenPhotoGalleryView(photoUrls: log.cleanPhotoUrls, selectedIndex: $selectedPhotoIndex)
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
    
    // MARK: - Delete Action
    
    private var deleteButton: some View {
        Button {
            isShowingDeleteConfirm = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash.fill")
                Text("Delete Climb Log")
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.red.opacity(0.10))
            .cornerRadius(12)
        }
        .padding(.top, 12)
        .alert("Delete Climb Log?", isPresented: $isShowingDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                actionViewModel.deleteLog(log) {
                    dismiss()
                }
            }
        } message: {
            Text("This action cannot be undone. The climb log and any attached photos will be permanently removed.")
        }
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
