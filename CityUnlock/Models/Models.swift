import Foundation
import CoreLocation

// MARK: - Building Type

enum BuildingType: String, Codable, CaseIterable {
    case residential
    case apartments
    case shop
    case supermarket
    case school
    case hospital
    case office
    case industrial
    case powerPlant
    case park
    case water
    case unknown

    var displayName: String {
        switch self {
        case .residential:  return "Жилой дом"
        case .apartments:   return "Жилой комплекс"
        case .shop:         return "Магазин"
        case .supermarket:  return "Супермаркет"
        case .school:       return "Школа"
        case .hospital:     return "Больница"
        case .office:       return "Офис"
        case .industrial:   return "Завод"
        case .powerPlant:   return "Электростанция"
        case .park:         return "Парк"
        case .water:        return "Водоём"
        case .unknown:      return "Здание"
        }
    }

    var emoji: String {
        switch self {
        case .residential:  return "🏠"
        case .apartments:   return "🏢"
        case .shop:         return "🛒"
        case .supermarket:  return "🏬"
        case .school:       return "🏫"
        case .hospital:     return "🏥"
        case .office:       return "🏛"
        case .industrial:   return "🏭"
        case .powerPlant:   return "⚡"
        case .park:         return "🌳"
        case .water:        return "💧"
        case .unknown:      return "🏗"
        }
    }

    /// Minimum player level required to unlock
    var requiredLevel: Int {
        switch self {
        case .residential:  return 1
        case .park:         return 1
        case .shop:         return 2
        case .school:       return 2
        case .hospital:     return 2
        case .apartments:   return 2
        case .office:       return 3
        case .supermarket:  return 3
        case .industrial:   return 4
        case .powerPlant:   return 4
        case .water:        return 1
        case .unknown:      return 1
        }
    }

    /// Passive income per hour when unlocked
    var incomePerHour: Int {
        switch self {
        case .residential:  return 2
        case .apartments:   return 6
        case .shop:         return 10
        case .supermarket:  return 20
        case .school:       return 8
        case .hospital:     return 10
        case .office:       return 14
        case .industrial:   return 25
        case .powerPlant:   return 40
        case .park:         return 3
        case .water:        return 1
        case .unknown:      return 2
        }
    }

    /// Points awarded when unlocked
    var basePoints: Int {
        switch self {
        case .residential:  return 10
        case .park:         return 5
        case .shop:         return 15
        case .school:       return 20
        case .hospital:     return 20
        case .apartments:   return 25
        case .office:       return 25
        case .supermarket:  return 30
        case .industrial:   return 50
        case .powerPlant:   return 60
        case .water:        return 3
        case .unknown:      return 5
        }
    }

    /// Cost in points to unlock
    var unlockCost: Int {
        switch self {
        case .residential:  return 0
        case .park:         return 0
        case .shop:         return 20
        case .school:       return 30
        case .hospital:     return 40
        case .apartments:   return 35
        case .office:       return 50
        case .supermarket:  return 60
        case .industrial:   return 120
        case .powerPlant:   return 200
        case .water:        return 0
        case .unknown:      return 10
        }
    }

    /// Isometric tile color (hex)
    var tileColor: String {
        switch self {
        case .residential, .apartments: return "#a8d898"
        case .shop, .supermarket:       return "#ffd54f"
        case .school, .hospital:        return "#90caf9"
        case .office:                   return "#ce93d8"
        case .industrial, .powerPlant:  return "#ffb74d"
        case .park:                     return "#4a9e45"
        case .water:                    return "#4a90d0"
        case .unknown:                  return "#b0b0b0"
        }
    }
}

// MARK: - Building State

enum BuildingState: String, Codable {
    case locked
    case constructing
    case unlocked
}

// MARK: - Building

struct Building: Identifiable, Codable {
    let id: String
    let osmId: Int64
    let name: String?
    let type: BuildingType
    let coordinates: [CLLocationCoordinate2D]
    let levels: Int
    let areaM2: Double

    var state: BuildingState = .locked

    // Isometric grid position (set after coordinate conversion)
    var isoX: Double = 0
    var isoY: Double = 0
    var isoWidth: Double = 1
    var isoHeight: Double = 1

    var displayName: String {
        name ?? type.displayName
    }

    /// Points earned = base × area factor × levels
    var earnedPoints: Int {
        let areaFactor = max(1.0, areaM2 / 100.0)
        let levelFactor = Double(max(1, levels))
        return Int(Double(type.basePoints) * min(areaFactor, 10.0) * min(levelFactor, 5.0))
    }

    var unlockCost: Int { type.unlockCost }
    var requiredLevel: Int { type.requiredLevel }

    enum CodingKeys: String, CodingKey {
        case id, osmId, name, type, levels, areaM2, state, isoX, isoY, isoWidth, isoHeight
        case coordinatesData
    }

    init(osmId: Int64, name: String?, type: BuildingType,
         coordinates: [CLLocationCoordinate2D], levels: Int, areaM2: Double) {
        self.id = "building_\(osmId)"
        self.osmId = osmId
        self.name = name
        self.type = type
        self.coordinates = coordinates
        self.levels = levels
        self.areaM2 = areaM2
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        osmId = try container.decode(Int64.self, forKey: .osmId)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        type = try container.decode(BuildingType.self, forKey: .type)
        levels = try container.decode(Int.self, forKey: .levels)
        areaM2 = try container.decode(Double.self, forKey: .areaM2)
        state = try container.decode(BuildingState.self, forKey: .state)
        isoX = try container.decode(Double.self, forKey: .isoX)
        isoY = try container.decode(Double.self, forKey: .isoY)
        isoWidth = try container.decode(Double.self, forKey: .isoWidth)
        isoHeight = try container.decode(Double.self, forKey: .isoHeight)
        let rawCoords = try container.decodeIfPresent([[Double]].self, forKey: .coordinatesData) ?? []
        coordinates = rawCoords.compactMap {
            guard $0.count == 2 else { return nil }
            return CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1])
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(osmId, forKey: .osmId)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(levels, forKey: .levels)
        try container.encode(areaM2, forKey: .areaM2)
        try container.encode(state, forKey: .state)
        try container.encode(isoX, forKey: .isoX)
        try container.encode(isoY, forKey: .isoY)
        try container.encode(isoWidth, forKey: .isoWidth)
        try container.encode(isoHeight, forKey: .isoHeight)
        try container.encode(coordinates.map { [$0.latitude, $0.longitude] }, forKey: .coordinatesData)
    }
}

// MARK: - City

struct City: Identifiable, Codable {
    let id: String
    let name: String
    let country: String
    let latitude: Double
    let longitude: Double
    let boundingBox: [Double] // [minLat, maxLat, minLon, maxLon]

    var displayName: String { "\(name), \(country)" }
}

// MARK: - Level Config

struct LevelConfig {
    let level: Int
    let pointsRequired: Int
    let title: String

    static let all: [LevelConfig] = [
        LevelConfig(level: 1, pointsRequired: 0,    title: "Основатель"),
        LevelConfig(level: 2, pointsRequired: 50,   title: "Строитель"),
        LevelConfig(level: 3, pointsRequired: 150,  title: "Архитектор"),
        LevelConfig(level: 4, pointsRequired: 400,  title: "Градостроитель"),
        LevelConfig(level: 5, pointsRequired: 1000, title: "Мэр города"),
    ]

    static func current(for points: Int) -> LevelConfig {
        all.filter { $0.pointsRequired <= points }.last ?? all[0]
    }

    static func next(for points: Int) -> LevelConfig? {
        all.first { $0.pointsRequired > points }
    }
}
