import Foundation
import CoreLocation
import SpriteKit

struct IsoConverter {

    let city: City
    let sceneSize: CGSize

    let tileW: CGFloat = 32
    let tileH: CGFloat = 16

    private var minLat: Double { city.boundingBox[0] }
    private var maxLat: Double { city.boundingBox[1] }
    private var minLon: Double { city.boundingBox[2] }
    private var maxLon: Double { city.boundingBox[3] }

    private var latRange: Double { max(maxLat - minLat, 0.001) }
    private var lonRange: Double { max(maxLon - minLon, 0.001) }

    // Размер сцены в тайлах
    private var gridSize: CGFloat { 500 }

    func isoPoint(lat: Double, lon: Double) -> CGPoint {
        print("🗺 isoPoint: lat=\(lat) lon=\(lon), minLat=\(minLat) maxLat=\(maxLat), sceneSize=\(sceneSize)")
        let nx = CGFloat((lon - minLon) / lonRange) * gridSize
        let ny = CGFloat(1.0 - (lat - minLat) / latRange) * gridSize

        let screenX = (nx - ny) * tileW
        let screenY = -(nx + ny) * tileH
        
        print("""
            nx=\(nx)
            ny=\(ny)
            screen=(\(screenX), \(screenY))
            """)

        return CGPoint(x: screenX, y: screenY)
    }

    func isoPoints(coords: [CLLocationCoordinate2D]) -> [CGPoint] {
        coords.map { isoPoint(lat: $0.latitude, lon: $0.longitude) }
    }

    func centroid(of points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        let x = points.map { $0.x }.reduce(0, +) / CGFloat(points.count)
        let y = points.map { $0.y }.reduce(0, +) / CGFloat(points.count)
        return CGPoint(x: x, y: y)
    }

    func buildingHeight(levels: Int) -> CGFloat {
        CGFloat(min(levels, 20)) * 4
    }

    func buildingSize(areaM2: Double) -> CGFloat {
        let s = sqrt(areaM2 / 100.0)
        return CGFloat(min(max(s, 0.5), 8.0)) * tileW * 0.5
    }
}
