//
//  CoordinateSelectionView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 8/9/26.
//

import SwiftUI
import MapKit
import GooglePlaces

struct CoordinateSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Binding to the selected coordinate to pass back
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    @Binding var selectedPlaceName: String?
    
    // Internal state for the map center and the currently dragged pin
    @State private var center: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 12.8797, longitude: 121.7740) // Default PH Center
    @State private var distance: CLLocationDistance = 1_200_000
    @State private var cameraTrigger = UUID()
    @State private var tempCoordinate: CLLocationCoordinate2D?
    @State private var currentPlaceName: String?
    
    // Search states
    @State private var searchText: String = ""
    @State private var searchPredictions: [GMSAutocompletePrediction] = []
    @State private var isSearching: Bool = false
    @State private var searchError: String? = nil
    @State private var ignoreSearchTextChange: Bool = false
    
    private func fetchPredictions(query: String) {
        guard !query.isEmpty else {
            searchPredictions = []
            return
        }
        
        let filter = GMSAutocompleteFilter()
        filter.country = "PH"
        let token = GMSAutocompleteSessionToken.init()
        
        GMSPlacesClient.shared().findAutocompletePredictions(fromQuery: query, filter: filter, sessionToken: token) { results, error in
            if let error = error {
                print("Autocomplete error: \(error.localizedDescription)")
                self.searchPredictions = []
                return
            }
            if let results = results {
                self.searchPredictions = results
            }
        }
    }
    
    private func selectPrediction(_ prediction: GMSAutocompletePrediction) {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        ignoreSearchTextChange = true
        searchText = prediction.attributedPrimaryText.string
        searchPredictions = []
        isSearching = true
        searchError = nil
        
        let fields: GMSPlaceField = GMSPlaceField(rawValue: UInt64(GMSPlaceField.coordinate.rawValue))
        
        GMSPlacesClient.shared().fetchPlace(fromPlaceID: prediction.placeID, placeFields: fields, sessionToken: nil) { place, error in
            isSearching = false
            if let error = error {
                searchError = "Failed to fetch place details: \(error.localizedDescription)"
                return
            }
            if let place = place {
                tempCoordinate = place.coordinate
                currentPlaceName = prediction.attributedPrimaryText.string
                center = place.coordinate
                distance = 5000
                cameraTrigger = UUID()
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                GoogleMapView(
                    centerCoordinate: center,
                    distance: distance,
                    annotationCoordinate: tempCoordinate,
                    annotationTitle: "Summit Location",
                    isInteractivePicker: true,
                    isDraggableAnnotation: true,
                    onAnnotationDrag: { newCoord in
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        searchPredictions = []
                        tempCoordinate = newCoord
                        currentPlaceName = nil
                    },
                    cameraTrigger: cameraTrigger
                )
                .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 12) {
                    // Instructions banner at the top
                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap.fill")
                            .foregroundColor(.gliderBlue)
                        Text("Tap or long-press on the map to place a pin")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    
                    // Search Bar
                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundColor(.gliderBlue)
                            TextField("Search mountain, summit, or trail...", text: $searchText)
                                .onChange(of: searchText) { newValue in
                                    if ignoreSearchTextChange {
                                        ignoreSearchTextChange = false
                                        return
                                    }
                                    fetchPredictions(query: newValue)
                                }
                                .submitLabel(.search)
                                .onSubmit {
                                    fetchPredictions(query: searchText)
                                }
                            if isSearching {
                                ProgressView().scaleEffect(0.7)
                            } else if !searchText.isEmpty {
                                Button(action: { fetchPredictions(query: searchText) }) {
                                    Text("Go").fontWeight(.bold).foregroundColor(.gliderBlue)
                                }
                            }
                        }
                        .padding(12)
                        
                        if !searchPredictions.isEmpty {
                            Divider()
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 0) {
                                    ForEach(searchPredictions, id: \.placeID) { prediction in
                                        Button(action: {
                                            selectPrediction(prediction)
                                        }) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(prediction.attributedPrimaryText.string)
                                                    .font(.subheadline)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.primary)
                                                if let secondary = prediction.attributedSecondaryText?.string {
                                                    Text(secondary)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            .padding(.vertical, 10)
                                            .padding(.horizontal, 12)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        Divider()
                                    }
                                }
                            }
                            .frame(maxHeight: 220)
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 3)
                    .padding(.horizontal, 16)
                    
                    if let error = searchError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.8))
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 12)
                .frame(maxHeight: .infinity, alignment: .top)
                
                // Confirmation Card
                if let temp = tempCoordinate {
                    VStack(spacing: 12) {
                        Text(String(format: "Selected: %.5f, %.5f", temp.latitude, temp.longitude))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Button {
                            selectedPlaceName = currentPlaceName
                            selectedCoordinate = temp
                            dismiss()
                        } label: {
                            Text("Confirm Location")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.gliderBlue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding(16)
                    .background(.thickMaterial)
                    .cornerRadius(18)
                    .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 5)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(), value: tempCoordinate != nil)
                }
            }
            .navigationTitle("Select Summit Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
            }
            .onAppear {
                if let initial = selectedCoordinate {
                    center = initial
                    tempCoordinate = initial
                    currentPlaceName = selectedPlaceName
                    distance = 5000
                    cameraTrigger = UUID()
                }
            }
        }
    }
}
