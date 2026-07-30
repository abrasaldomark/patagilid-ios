//
//  MountainMapView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/30/26.
//

import SwiftUI
import MapKit

/// A responsive, offline-capable internal MapKit viewing modal for inspecting peak terrain and coordinates.
struct MountainMapView: View {
    let mountain: Mountain
    @Environment(\.dismiss) private var dismiss
    @State private var position: MapCameraPosition
    
    init(mountain: Mountain) {
        self.mountain = mountain
        let center = CLLocationCoordinate2D(latitude: mountain.latitude, longitude: mountain.longitude)
        _position = State(initialValue: .camera(MapCamera(centerCoordinate: center, distance: 8000)))
    }
    
    var body: some View {
        NavigationStack {
            Map(position: $position) {
                Annotation("", coordinate: CLLocationCoordinate2D(latitude: mountain.latitude, longitude: mountain.longitude)) {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 38, height: 38)
                                .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
                            
                            Circle()
                                .fill(Color.gliderBlue)
                                .frame(width: 30, height: 30)
                            
                            Image(systemName: "mountain.2.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        Text(mountain.name)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.8))
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                }
            }
            .mapStyle(.hybrid(elevation: .flat, pointsOfInterest: .all))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .navigationTitle(mountain.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.gliderBlue)
                    .fontWeight(.semibold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        let center = CLLocationCoordinate2D(latitude: mountain.latitude, longitude: mountain.longitude)
                        withAnimation(.easeInOut(duration: 0.5)) {
                            position = .camera(MapCamera(centerCoordinate: center, distance: 8000))
                        }
                    } label: {
                        Image(systemName: "location.north.circle.fill")
                            .font(.title3)
                            .foregroundColor(.gliderBlue)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 8) {
                    Image(systemName: "triangle.tophalf.filled")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.gliderBlue)
                    Text("\(mountain.elevationMASL) MASL")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(String(format: "%.4f, %.4f", mountain.latitude, mountain.longitude))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color(.systemBackground).opacity(0.92))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.summitSteel.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
                .padding(.bottom, 12)
            }
        }
    }
}
