import Foundation
import Combine
import CoreLocation

class GameState: ObservableObject {
    @Published var city: City?
    @Published var buildings: [Building] = []
    @Published var roads: [[CLLocationCoordinate2D]] = []
    @Published var totalPoints: Int = 0  // XP
    @Published var coins: Int = 0        // Money
    @Published var pendingIncome: Int = 0
    @Published var isLoading: Bool = false
    @Published var loadingMessage: String = ""
    @Published var selectedBuilding: Building?

    var loadedRegions: Set<String> = []
    private let maxOfflineHours: Double = 8

    // MARK: - Computed

    var totalIncomePerHour: Int {
        buildings.filter { $0.state == .unlocked }.map { $0.type.incomePerHour }.reduce(0, +)
    }

    var currentLevel: LevelConfig { LevelConfig.current(for: totalPoints) }
    var nextLevel: LevelConfig?   { LevelConfig.next(for: totalPoints) }

    var progressToNextLevel: Double {
        guard let next = nextLevel else { return 1.0 }
        let range = Double(next.pointsRequired - currentLevel.pointsRequired)
        let progress = Double(totalPoints - currentLevel.pointsRequired)
        return min(progress / range, 1.0)
    }

    // MARK: - Session restore

    /// Call on app launch — restores city + buildings + progress if available
    func restoreSession() {
        guard let cityData = UserDefaults.standard.data(forKey: "savedCity"),
              let savedCity = try? JSONDecoder().decode(City.self, from: cityData),
              let buildingData = UserDefaults.standard.data(forKey: "buildings_\(savedCity.id)"),
              let savedBuildings = try? JSONDecoder().decode([Building].self, from: buildingData),
              savedBuildings.first?.coordinates.isEmpty == false
        else { return }

        city = savedCity
        buildings = savedBuildings
        totalPoints = UserDefaults.standard.integer(forKey: "totalPoints")
        coins = UserDefaults.standard.integer(forKey: "coins")
        loadedRegions.insert("\(Int(savedCity.latitude / 0.05))_\(Int(savedCity.longitude / 0.05))")
    }

    // MARK: - Offline income

    func calculateOfflineIncome() {
        let key = "lastActiveDate"
        let now = Date()
        if let last = UserDefaults.standard.object(forKey: key) as? Date {
            let hours = min(now.timeIntervalSince(last) / 3600, maxOfflineHours)
            let earned = Int(Double(totalIncomePerHour) * hours)
            if earned > 0 { pendingIncome = earned }
        }
        UserDefaults.standard.set(now, forKey: key)
    }

    func collectIncome() {
        coins += pendingIncome
        pendingIncome = 0
        saveProgress()
    }

    // MARK: - Buildings

    func mergeBuildings(_ newBuildings: [Building]) {
        let existingIDs = Set(buildings.map(\.osmId))
        let fresh = newBuildings.filter { !existingIDs.contains($0.osmId) }
        guard !fresh.isEmpty else { return }
        buildings.append(contentsOf: fresh)
    }

    // MARK: - Actions

    func unlock(building: Building) {
        guard let index = buildings.firstIndex(where: { $0.id == building.id }) else { return }
        guard coins >= building.unlockCost else { return }
        guard currentLevel.level >= building.requiredLevel else { return }

        coins -= building.unlockCost
        buildings[index].state = .constructing
        selectedBuilding = nil
        saveProgress()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if let i = self.buildings.firstIndex(where: { $0.id == building.id }) {
                self.buildings[i].state = .unlocked
                self.totalPoints += self.buildings[i].earnedPoints
                self.saveProgress()
            }
        }
    }

    func canUnlock(_ building: Building) -> Bool {
        building.state == .locked &&
        coins >= building.unlockCost &&
        currentLevel.level >= building.requiredLevel
    }

    // MARK: - Persistence

    func saveProgress() {
        guard let cityId = city?.id else { return }
        let encoder = JSONEncoder()
        if let cityData = try? encoder.encode(city) {
            UserDefaults.standard.set(cityData, forKey: "savedCity")
        }
        if let data = try? encoder.encode(buildings) {
            UserDefaults.standard.set(data, forKey: "buildings_\(cityId)")
        }
        UserDefaults.standard.set(totalPoints, forKey: "totalPoints")
        UserDefaults.standard.set(coins, forKey: "coins")
    }

    func loadCached(for cityId: String) -> [Building]? {
        guard let data = UserDefaults.standard.data(forKey: "buildings_\(cityId)"),
              let saved = try? JSONDecoder().decode([Building].self, from: data),
              saved.first?.coordinates.isEmpty == false else { return nil }
        return saved
    }

    func loadProgress() {
        totalPoints = UserDefaults.standard.integer(forKey: "totalPoints")
        coins = UserDefaults.standard.integer(forKey: "coins")
        if let cityId = city?.id,
           let data = UserDefaults.standard.data(forKey: "buildings_\(cityId)"),
           let saved = try? JSONDecoder().decode([Building].self, from: data) {
            for s in saved {
                if let i = buildings.firstIndex(where: { $0.id == s.id }) {
                    buildings[i].state = s.state
                }
            }
        }
    }

    func reset() {
        city = nil
        buildings = []
        totalPoints = 0
        coins = 0
        selectedBuilding = nil
        loadedRegions.removeAll()
        UserDefaults.standard.removeObject(forKey: "savedCity")
    }
}
