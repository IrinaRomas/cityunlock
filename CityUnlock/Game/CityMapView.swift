import SwiftUI
import MapKit

// MARK: - Annotation

class BuildingAnnotation: NSObject, MKAnnotation {
    let building: Building
    let coordinate: CLLocationCoordinate2D
    var title: String? { building.displayName }

    init(building: Building, coordinate: CLLocationCoordinate2D) {
        self.building = building
        self.coordinate = coordinate
    }
}

// MARK: - Map View

struct CityMapView: UIViewRepresentable {
    let city: City
    let buildings: [Building]
    let totalPoints: Int
    let playerLevel: Int
    let onTap: (Building) -> Void
    let onRegionChange: (MKCoordinateRegion) -> Void

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.mapType = .standard
        map.showsBuildings = false
        map.showsTraffic = false
        map.pointOfInterestFilter = .excludingAll

        let center = CLLocationCoordinate2D(latitude: city.latitude, longitude: city.longitude)
        map.setRegion(MKCoordinateRegion(center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)),
            animated: false)

        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        map.addGestureRecognizer(tap)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.onTap = onTap
        context.coordinator.onRegionChange = onRegionChange
        context.coordinator.totalPoints = totalPoints
        context.coordinator.playerLevel = playerLevel
        context.coordinator.update(map, buildings: buildings)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var onTap: (Building) -> Void = { _ in }
        var onRegionChange: (MKCoordinateRegion) -> Void = { _ in }
        var totalPoints: Int = 0
        var playerLevel: Int = 1
        private var buildings: [String: Building] = [:]
        private var polygons: [String: MKPolygon] = [:] // id → polygon

        func update(_ map: MKMapView, buildings newBuildings: [Building]) {
            guard !newBuildings.isEmpty else { return }

            for b in newBuildings {
                let old = buildings[b.id]
                buildings[b.id] = b

                if old == nil {
                    // New building — add polygon
                    guard b.coordinates.count >= 3 else { continue }
                    let polygon = MKPolygon(coordinates: b.coordinates, count: b.coordinates.count)
                    polygon.title = b.id
                    polygons[b.id] = polygon
                    map.addOverlay(polygon, level: .aboveRoads)
                } else if old?.state != b.state, let polygon = polygons[b.id] {
                    // State changed — replace overlay to force renderer refresh
                    map.removeOverlay(polygon)
                    let newPolygon = MKPolygon(coordinates: b.coordinates, count: b.coordinates.count)
                    newPolygon.title = b.id
                    polygons[b.id] = newPolygon
                    map.addOverlay(newPolygon, level: .aboveRoads)
                }
            }
        }

        // MARK: Overlay renderer

        func mapView(_ map: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polygon = overlay as? MKPolygon,
                  let id = polygon.title,
                  let building = buildings[id] else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let r = MKPolygonRenderer(polygon: polygon)
            let canAfford = totalPoints >= building.unlockCost && playerLevel >= building.requiredLevel
            switch building.state {
            case .locked:
                r.fillColor   = canAfford ? UIColor.systemOrange.withAlphaComponent(0.45)
                                          : UIColor.systemGray.withAlphaComponent(0.25)
                r.strokeColor = canAfford ? .systemOrange : .systemGray3
                r.lineWidth   = canAfford ? 2.0 : 1.0
            case .constructing:
                r.fillColor   = UIColor.systemYellow.withAlphaComponent(0.7)
                r.strokeColor = .orange
                r.lineWidth   = 1.5
            case .unlocked:
                r.fillColor   = fillColor(building.type)
                r.strokeColor = UIColor.white.withAlphaComponent(0.5)
                r.lineWidth   = 1.0
            }
            return r
        }

        // MARK: Annotation view

        func mapView(_ map: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            return nil
        }

        // MARK: Tap handling — ray casting in MKMapPoint space

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let map = gesture.view as? MKMapView else { return }
            let pt = gesture.location(in: map)
            let coord = map.convert(pt, toCoordinateFrom: map)
            let tapMP = MKMapPoint(coord)

            for overlay in map.overlays {
                guard let polygon = overlay as? MKPolygon,
                      let id = polygon.title,
                      let building = buildings[id] else { continue }
                if polygon.containsMapPoint(tapMP) {
                    onTap(building)
                    return
                }
            }
        }

        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

        // MARK: Progressive loading on scroll

        private var loadTask: Task<Void, Never>?

        func mapView(_ map: MKMapView, regionDidChangeAnimated animated: Bool) {
            onRegionChange(map.region)
        }

        // MARK: Colors

        private func fillColor(_ type: BuildingType) -> UIColor {
            switch type {
            case .residential, .apartments: return UIColor(red: 0.47, green: 0.78, blue: 0.47, alpha: 0.7)
            case .shop, .supermarket:       return UIColor(red: 1.0,  green: 0.80, blue: 0.20, alpha: 0.7)
            case .school:                   return UIColor(red: 0.37, green: 0.70, blue: 0.93, alpha: 0.7)
            case .hospital:                 return UIColor(red: 0.95, green: 0.40, blue: 0.40, alpha: 0.7)
            case .office:                   return UIColor(red: 0.72, green: 0.45, blue: 0.85, alpha: 0.7)
            case .industrial, .powerPlant:  return UIColor(red: 1.0,  green: 0.60, blue: 0.20, alpha: 0.7)
            case .park:                     return UIColor(red: 0.25, green: 0.70, blue: 0.25, alpha: 0.7)
            case .water:                    return UIColor(red: 0.30, green: 0.65, blue: 0.90, alpha: 0.7)
            default:                        return UIColor.systemGray4.withAlphaComponent(0.6)
            }
        }

        private func tintColor(_ building: Building) -> UIColor {
            switch building.state {
            case .locked:
                let canAfford = false
                return canAfford ? .systemOrange : .systemGray
            case .constructing: return .systemYellow
            case .unlocked:
                switch building.type {
                case .residential, .apartments: return .systemGreen
                case .shop, .supermarket:       return .systemYellow
                case .school:                   return .systemBlue
                case .hospital:                 return .systemRed
                case .office:                   return .systemPurple
                case .industrial, .powerPlant:  return .systemOrange
                case .park:                     return .systemTeal
                default:                        return .systemGray
                }
            }
        }
    }
}

// MARK: - Helpers

private extension Array where Element == CLLocationCoordinate2D {
    var centroid: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude:  map(\.latitude).reduce(0, +)  / Double(count),
            longitude: map(\.longitude).reduce(0, +) / Double(count)
        )
    }
}

private extension MKPolygon {
    func containsMapPoint(_ point: MKMapPoint) -> Bool {
        let pts = self.points()
        let count = self.pointCount
        guard count >= 3 else { return false }
        var inside = false
        var j = count - 1
        for i in 0..<count {
            let pi = pts[i], pj = pts[j]
            if ((pi.y > point.y) != (pj.y > point.y)) &&
               (point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x) {
                inside = !inside
            }
            j = i
        }
        return inside
    }
}
