import Foundation
import CoreLocation

class OverpassService {
    static let shared = OverpassService()
    private let baseURL = "https://overpass-api.de/api/interpreter"

    func loadRoads(for city: City) async throws -> [[CLLocationCoordinate2D]] {
        let bb = city.boundingBox
        let bbox = "\(bb[0]),\(bb[2]),\(bb[1]),\(bb[3])"

        let query = """
        [out:json][timeout:30];
        way["highway"~"^(primary|secondary|tertiary|residential|trunk|motorway)$"](\(bbox));
        out body;
        >;
        out skel qt;
        """

        guard let url = URL(string: baseURL) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = "data=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")".data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("CityUnlockGame/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 60

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(OverpassResponse.self, from: data)

        var nodes: [Int64: CLLocationCoordinate2D] = [:]
        for el in response.elements where el.type == "node" {
            if let lat = el.lat, let lon = el.lon {
                nodes[el.id] = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        }

        return response.elements
            .filter { $0.type == "way" }
            .compactMap { el -> [CLLocationCoordinate2D]? in
                guard let refs = el.nodes else { return nil }
                let coords = refs.compactMap { nodes[$0] }
                return coords.count >= 2 ? coords : nil
            }
    }

    func loadBuildings(for city: City) async throws -> [Building] {
        let bb = city.boundingBox
        let bbox = "\(bb[0]),\(bb[2]),\(bb[1]),\(bb[3])"
        return try await loadBuildings(bbox: bbox)
    }

    func loadBuildings(bbox: String) async throws -> [Building] {

        let query = """
        [out:json][timeout:60];
        (
          way["building"](\(bbox));
          way["amenity"~"school|hospital|university|college|clinic"](\(bbox));
          way["shop"~"supermarket|mall|convenience"](\(bbox));
          way["landuse"~"industrial|commercial"](\(bbox));
          way["power"="plant"](\(bbox));
          way["leisure"="park"](\(bbox));
        );
        out body;
        >;
        out skel qt;
        """

        guard let url = URL(string: baseURL) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = "data=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")".data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("CityUnlockGame/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 90

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(OverpassResponse.self, from: data)

        return parseBuildings(from: response)
    }

    // MARK: - Parsing

    private func parseBuildings(from response: OverpassResponse) -> [Building] {
        // Build node lookup: id → coordinate
        var nodes: [Int64: CLLocationCoordinate2D] = [:]
        for element in response.elements where element.type == "node" {
            if let lat = element.lat, let lon = element.lon {
                nodes[element.id] = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        }

        var buildings: [Building] = []

        for element in response.elements where element.type == "way" {
            guard let refs = element.nodes, !refs.isEmpty else { continue }

            let coords = refs.compactMap { nodes[$0] }
            guard coords.count >= 3 else { continue }

            let area = polygonArea(coords: coords)
            guard area > 10 else { continue } // skip tiny shapes

            let type = buildingType(from: element.tags)
            let name = element.tags?["name"] ?? element.tags?["name:uk"] ?? element.tags?["name:ru"]
            let levels = Int(element.tags?["building:levels"] ?? "1") ?? 1

            let building = Building(
                osmId: element.id,
                name: name,
                type: type,
                coordinates: coords,
                levels: min(levels, 50),
                areaM2: area
            )
            buildings.append(building)
        }

        return buildings
    }

    private func buildingType(from tags: [String: String]?) -> BuildingType {
        guard let tags = tags else { return .unknown }

        if let amenity = tags["amenity"] {
            switch amenity {
            case "school", "kindergarten": return .school
            case "hospital", "clinic":     return .hospital
            case "university", "college":  return .office
            default: break
            }
        }

        if let shop = tags["shop"] {
            switch shop {
            case "supermarket", "mall": return .supermarket
            default: return .shop
            }
        }

        if tags["power"] == "plant" { return .powerPlant }
        if tags["leisure"] == "park" { return .park }

        if let landuse = tags["landuse"] {
            switch landuse {
            case "industrial":  return .industrial
            case "commercial":  return .shop
            default: break
            }
        }

        if let building = tags["building"] {
            switch building {
            case "residential", "house", "detached",
                 "farm", "terrace", "bungalow",
                 "yes", "roof":                      return .residential
            case "apartments", "dormitory",
                 "block", "flat":                    return .apartments
            case "commercial", "retail",
                 "kiosk", "store":                   return .shop
            case "industrial", "warehouse",
                 "manufacture", "factory":           return .industrial
            case "school":                           return .school
            case "hospital", "clinic":               return .hospital
            case "office", "government",
                 "public", "civic":                  return .office
            default: break
            }
        }

        return .unknown
    }

    /// Approximate polygon area in m² using Shoelace formula + lat/lon scaling
    private func polygonArea(coords: [CLLocationCoordinate2D]) -> Double {
        guard coords.count >= 3 else { return 0 }
        let latScale = 111_320.0
        let lonScale = 111_320.0 * cos(coords[0].latitude * .pi / 180)

        var area = 0.0
        let n = coords.count
        for i in 0..<n {
            let j = (i + 1) % n
            let xi = coords[i].longitude * lonScale
            let yi = coords[i].latitude * latScale
            let xj = coords[j].longitude * lonScale
            let yj = coords[j].latitude * latScale
            area += xi * yj - xj * yi
        }
        return abs(area) / 2.0
    }
}

// MARK: - Overpass response models

private struct OverpassResponse: Codable {
    let elements: [OverpassElement]
}

private struct OverpassElement: Codable {
    let id: Int64
    let type: String
    let lat: Double?
    let lon: Double?
    let nodes: [Int64]?
    let tags: [String: String]?
}
