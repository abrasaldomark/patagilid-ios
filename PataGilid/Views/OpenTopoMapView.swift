//
//  OpenTopoMapView.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 8/3/26.
//

import SwiftUI
import MapKit

/// A native SwiftUI map adapter that replaces default map imagery with open-source topographic hiking tiles from OpenTopoMap.
struct OpenTopoMapView: UIViewRepresentable {
    var centerCoordinate: CLLocationCoordinate2D
    var distance: CLLocationDistance
    var annotationCoordinate: CLLocationCoordinate2D?
    var annotationTitle: String
    var isInteractivePicker: Bool
    var isDraggableAnnotation: Bool = false
    var onAnnotationDrag: ((CLLocationCoordinate2D) -> Void)? = nil
    var onSelectCoordinate: ((CLLocationCoordinate2D) -> Void)?
    var cameraTrigger: UUID

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.mapType = .standard
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.isPitchEnabled = false

        // Add robust OpenTopoMap Tile Overlay with required User-Agent header and caching
        let overlay = OpenTopoTileOverlay()
        mapView.addOverlay(overlay, level: .aboveRoads)

        // Set Initial Region
        let region = MKCoordinateRegion(
            center: centerCoordinate,
            latitudinalMeters: distance,
            longitudinalMeters: distance
        )
        mapView.setRegion(region, animated: false)

        if isInteractivePicker {
            let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapTap(_:)))
            tapGesture.numberOfTapsRequired = 1
            
            // Prevent single-tap pin placement from firing when double-tapping to zoom the map
            for gesture in mapView.gestureRecognizers ?? [] {
                if let tap = gesture as? UITapGestureRecognizer, tap.numberOfTapsRequired == 2 {
                    tapGesture.require(toFail: tap)
                }
            }
            for subview in mapView.subviews {
                for gesture in subview.gestureRecognizers ?? [] {
                    if let tap = gesture as? UITapGestureRecognizer, tap.numberOfTapsRequired == 2 {
                        tapGesture.require(toFail: tap)
                    }
                }
            }
            
            mapView.addGestureRecognizer(tapGesture)
        }
        
        if isInteractivePicker || isDraggableAnnotation {
            let longPressGesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
            longPressGesture.minimumPressDuration = 0.4
            mapView.addGestureRecognizer(longPressGesture)
        }

        context.coordinator.lastCameraTrigger = cameraTrigger
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self

        // Handle programmatic camera moves (e.g., Nominatim search results or "Locate" button taps)
        if context.coordinator.lastCameraTrigger != cameraTrigger {
            context.coordinator.lastCameraTrigger = cameraTrigger
            let region = MKCoordinateRegion(
                center: centerCoordinate,
                latitudinalMeters: distance,
                longitudinalMeters: distance
            )
            mapView.setRegion(region, animated: true)
        }

        // Synchronize pin annotations without UI flicker
        if let newCoord = annotationCoordinate {
            if let existing = mapView.annotations.first as? MKPointAnnotation {
                if abs(existing.coordinate.latitude - newCoord.latitude) > 0.000001 ||
                   abs(existing.coordinate.longitude - newCoord.longitude) > 0.000001 ||
                   existing.title != annotationTitle {
                    existing.coordinate = newCoord
                    existing.title = annotationTitle
                    if let annotationView = mapView.view(for: existing) as? TopoAnnotationView {
                        annotationView.configure(title: annotationTitle, isInteractive: isInteractivePicker)
                    }
                }
            } else {
                mapView.removeAnnotations(mapView.annotations)
                let ann = MKPointAnnotation()
                ann.coordinate = newCoord
                ann.title = annotationTitle
                mapView.addAnnotation(ann)
            }
        } else {
            if !mapView.annotations.isEmpty {
                mapView.removeAnnotations(mapView.annotations)
            }
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: OpenTopoMapView
        var lastCameraTrigger: UUID?

        init(_ parent: OpenTopoMapView) {
            self.parent = parent
        }

        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended, let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            parent.onSelectCoordinate?(coordinate)
        }
        
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began, let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            parent.onAnnotationDrag?(coordinate)
            parent.onSelectCoordinate?(coordinate)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tileOverlay)
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            let identifier = "TopoPin"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? TopoAnnotationView
            if view == nil {
                view = TopoAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                view?.annotation = annotation
            }
            let pinTitle = (annotation.title ?? nil) ?? ""
            view?.configure(title: pinTitle, isInteractive: parent.isInteractivePicker || parent.isDraggableAnnotation)
            view?.isDraggable = parent.isInteractivePicker || parent.isDraggableAnnotation
            return view
        }
        
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, didChange newState: MKAnnotationView.DragState, fromOldState oldState: MKAnnotationView.DragState) {
            if newState == .ending || newState == .none {
                if let coordinate = view.annotation?.coordinate {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    parent.onAnnotationDrag?(coordinate)
                    parent.onSelectCoordinate?(coordinate)
                }
            }
        }
    }
}

/// Custom MKAnnotationView hosting clean SwiftUI mountain pin design directly above OpenTopoMap layers.
private class TopoAnnotationView: MKAnnotationView {
    private var hostingController: UIHostingController<TopoPinView>?

    func configure(title: String, isInteractive: Bool) {
        let pinView = TopoPinView(title: title, isInteractive: isInteractive)
        if let host = hostingController {
            host.rootView = pinView
        } else {
            let host = UIHostingController(rootView: pinView)
            host.view.backgroundColor = .clear
            let frame = CGRect(x: 0, y: 0, width: 160, height: 70)
            host.view.frame = frame
            self.frame = frame
            addSubview(host.view)
            self.hostingController = host
        }
        self.centerOffset = CGPoint(x: 0, y: -15)
        self.canShowCallout = false
    }
}

private struct TopoPinView: View {
    let title: String
    let isInteractive: Bool

    var body: some View {
        VStack(spacing: 4) {
            if isInteractive {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.red)
                    .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
            } else {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 36, height: 36)
                        .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
                    
                    Circle()
                        .fill(Color.gliderBlue)
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: "mountain.2.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            if !title.isEmpty {
                Text(title)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.85))
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            }
        }
    }
}

/// A robust MKTileOverlay serving enterprise-grade Esri World Topo terrain with 100% complete coverage at all zoom levels.
private class OpenTopoTileOverlay: MKTileOverlay {
    init() {
        // Esri World Topo Map: Professional GIS topographic shaded relief with complete global tile coverage
        super.init(urlTemplate: "https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}")
        self.canReplaceMapContent = true
    }
    
    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        let url = self.url(forTilePath: path)
        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 6)
        request.setValue("PataGilid-iOS-App/1.0 (contact@patagilid.app)", forHTTPHeaderField: "User-Agent")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, let data = data {
                result(data, nil)
            } else {
                // High-speed fallback to standard OpenStreetMap tiles if needed
                let fallbackUrlString = "https://tile.openstreetmap.org/\(path.z)/\(path.x)/\(path.y).png"
                guard let fallbackUrl = URL(string: fallbackUrlString) else {
                    result(nil, error ?? URLError(.badServerResponse))
                    return
                }
                var fallbackRequest = URLRequest(url: fallbackUrl, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 6)
                fallbackRequest.setValue("PataGilid-iOS-App/1.0 (contact@patagilid.app)", forHTTPHeaderField: "User-Agent")
                
                URLSession.shared.dataTask(with: fallbackRequest) { fallbackData, fallbackResponse, fallbackError in
                    if let httpResponse = fallbackResponse as? HTTPURLResponse, httpResponse.statusCode == 200, let data = fallbackData {
                        result(data, nil)
                    } else {
                        result(nil, fallbackError ?? error ?? URLError(.badServerResponse))
                    }
                }.resume()
            }
        }
        task.resume()
    }
}
