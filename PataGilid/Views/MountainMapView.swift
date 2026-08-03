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
    @State private var center: CLLocationCoordinate2D
    @State private var distance: CLLocationDistance
    @State private var cameraTrigger: UUID = UUID()
    
    init(mountain: Mountain) {
        self.mountain = mountain
        if let lat = mountain.latitude, let lon = mountain.longitude {
            _center = State(initialValue: CLLocationCoordinate2D(latitude: lat, longitude: lon))
            _distance = State(initialValue: 5000)
        } else {
            // Geographic center of the Philippines fallback if awaiting coordinates
            _center = State(initialValue: CLLocationCoordinate2D(latitude: 12.8797, longitude: 121.7740))
            _distance = State(initialValue: 1_200_000)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                OpenTopoMapView(
                    centerCoordinate: center,
                    distance: distance,
                    annotationCoordinate: (mountain.latitude != nil && mountain.longitude != nil) ? CLLocationCoordinate2D(latitude: mountain.latitude!, longitude: mountain.longitude!) : nil,
                    annotationTitle: mountain.name,
                    isInteractivePicker: false,
                    onSelectCoordinate: nil,
                    cameraTrigger: cameraTrigger
                )
                .edgesIgnoringSafeArea(.all)
                
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
                    
                    if let lat = mountain.latitude, let lon = mountain.longitude {
                        Text(String(format: "%.4f, %.4f", lat, lon))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Coordinates needed")
                            .font(.footnote)
                            .italic()
                            .foregroundColor(.orange)
                    }
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
                .padding(.bottom, 20)
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
                    if let lat = mountain.latitude, let lon = mountain.longitude {
                        Button {
                            center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                            distance = 5000
                            cameraTrigger = UUID()
                        } label: {
                            Image(systemName: "location.north.circle.fill")
                                .font(.title3)
                                .foregroundColor(.gliderBlue)
                        }
                    }
                }
            }
        }
    }
}
