import Foundation

class NominatimService {
    static let shared = NominatimService()
    private let baseURL = "https://nominatim.openstreetmap.org"

    func searchCities(query: String) async throws -> [City] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "\(baseURL)/search?q=\(encoded)&format=json&limit=8&addressdetails=1&namedetails=1"

        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.setValue("CityUnlockGame/1.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)

        // Парсим вручную через JSONSerialization — самый надёжный способ
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        print("Raw results count: \(json.count)")

        return json.compactMap { item -> City? in
            guard let lat = Double(item["lat"] as? String ?? ""),
                  let lon = Double(item["lon"] as? String ?? ""),
                  let bb = item["boundingbox"] as? [String],
                  bb.count == 4,
                  let minLat = Double(bb[0]),
                  let maxLat = Double(bb[1]),
                  let minLon = Double(bb[2]),
                  let maxLon = Double(bb[3]) else {
                print("Skipped item: \(item["display_name"] ?? "unknown")")
                return nil
            }

            // Имя города
            let address = item["address"] as? [String: Any]
            let namedetails = item["namedetails"] as? [String: Any]

            let name = (address?["city"] as? String)
                ?? (address?["town"] as? String)
                ?? (address?["village"] as? String)
                ?? (namedetails?["name:ru"] as? String)
                ?? (namedetails?["name"] as? String)
                ?? (item["display_name"] as? String ?? "").components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces)
                ?? "Неизвестный город"

            let country = (address?["country"] as? String) ?? ""
            let osmId = item["osm_id"] as? Int64 ?? Int64(item["place_id"] as? Int ?? 0)

            print("Found: \(name), \(country)")

            return City(
                id: "city_\(osmId)",
                name: name,
                country: country,
                latitude: lat,
                longitude: lon,
                boundingBox: [minLat, maxLat, minLon, maxLon]
            )
        }
    }
}
