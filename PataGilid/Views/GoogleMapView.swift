import SwiftUI
import GoogleMaps

struct GoogleMapView: UIViewRepresentable {
    var centerCoordinate: CLLocationCoordinate2D
    var distance: CLLocationDistance
    var annotationCoordinate: CLLocationCoordinate2D?
    var annotationTitle: String?
    
    var isInteractivePicker: Bool
    var isDraggableAnnotation: Bool
    var onAnnotationDrag: ((CLLocationCoordinate2D) -> Void)?
    
    var cameraTrigger: UUID
    
    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(
            withTarget: centerCoordinate,
            zoom: calculateZoomLevel(for: distance)
        )
        
        let mapView = GMSMapView.map(withFrame: .zero, camera: camera)
        mapView.delegate = context.coordinator
        mapView.mapType = .terrain
        
        return mapView
    }
    
    func updateUIView(_ mapView: GMSMapView, context: Context) {
        if context.coordinator.lastCameraTrigger != cameraTrigger {
            context.coordinator.lastCameraTrigger = cameraTrigger
            let camera = GMSCameraPosition.camera(
                withTarget: centerCoordinate,
                zoom: calculateZoomLevel(for: distance)
            )
            mapView.animate(to: camera)
        }
        
        mapView.clear()
        
        if let coord = annotationCoordinate {
            let marker = GMSMarker(position: coord)
            marker.title = annotationTitle ?? "Pinned Location"
            marker.isDraggable = isDraggableAnnotation
            marker.map = mapView
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func calculateZoomLevel(for distance: CLLocationDistance) -> Float {
        // Simple heuristic: Google Maps zoom levels go from 0 to roughly 20.
        // A distance of 5000m roughly corresponds to zoom 13.
        // 1.2M m corresponds to zoom 6.
        if distance > 100_000 {
            return 6.0
        } else {
            return 13.0
        }
    }
    
    class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: GoogleMapView
        var lastCameraTrigger: UUID
        
        init(_ parent: GoogleMapView) {
            self.parent = parent
            self.lastCameraTrigger = parent.cameraTrigger
        }
        
        func mapView(_ mapView: GMSMapView, didEndDragging marker: GMSMarker) {
            parent.onAnnotationDrag?(marker.position)
        }
        
        func mapView(_ mapView: GMSMapView, didLongPressAt coordinate: CLLocationCoordinate2D) {
            if parent.isDraggableAnnotation {
                parent.onAnnotationDrag?(coordinate)
            }
        }
        
        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            if parent.isInteractivePicker {
                parent.onAnnotationDrag?(coordinate)
            }
        }
    }
}
