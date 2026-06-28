import Foundation
import Combine
import CoreLocation

class GameState: ObservableObject {
    @Published var city: City?
    @Published var buildings: [Building] = []
    @Published var roads: [[CLLocationCoordinate2D]] = []
    @Published var pendingIncome: Int = 0
    var loadedRegions: Set<String> = []

    private let maxOfflineHours: Double = 8

    var totalIncomePerHour: Int {
        buildings.filter { $0.state == .unlocked }.map { $0.type.incomePerHour }.reduce(0, +)
    }

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
        totalPoints += pendingIncome
        pendingIncome = 0
        saveProgress()
    }

    func mergeBuildings(_ newBuildings: [Building]) {
        let existingIDs = Set(buildings.map(\.osmId))
        let fresh = newBuildings.filter { !existingIDs.contains($0.osmId) }
        guard !fresh.isEmpty else { return }
        buildings.append(contentsOf: fresh)
    }
    @Published var totalPoints: Int = 0
    @Published var isLoading: Bool = false
    @Published var loadingMessage: String = ""
    @Published var selectedBuilding: Building?

    var currentLevel: LevelConfig {
        LevelConfig.current(for: totalPoints)
    }

    var nextLevel: LevelConfig? {
        LevelConfig.next(for: totalPoints)
    }

    var progressToNextLevel: Double {
        guard let next = nextLevel else { return 1.0 }
        let current = currentLevel
        let range = Double(next.pointsRequired - current.pointsRequired)
        let progress = Double(totalPoints - current.pointsRequired)
        return min(progress / range, 1.0)
    }

    // MARK: - Actions

    func unlock(building: Building) {
        guard let index = buildings.firstIndex(where: { $0.id == building.id }) else { return }
        guard totalPoints >= building.unlockCost else { return }
        guard currentLevel.level >= building.requiredLevel else { return }

        totalPoints -= building.unlockCost
        buildings[index].state = .constructing

        // After 2s construction animation → unlocked
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if let i = self.buildings.firstIndex(where: { $0.id == building.id }) {
                self.buildings[i].state = .unlocked
                self.totalPoints += self.buildings[i].earnedPoints
                self.saveProgress()
            }
        }
        selectedBuilding = nil
        saveProgress()
    }

    func canUnlock(_ building: Building) -> Bool {
        building.state == .locked &&
        totalPoints >= building.unlockCost &&
        currentLevel.level >= building.requiredLevel
    }

    // MARK: - Persistence

    func saveProgress() {
        let data = try? JSONEncoder().encode(buildings)
        UserDefaults.standard.set(data, forKey: "buildings_\(city?.id ?? "")")
        UserDefaults.standard.set(totalPoints, forKey: "totalPoints")
    }

    /// Returns cached buildings for city if available (with coordinates)
    func loadCached(for cityId: String) -> [Building]? {
        guard let data = UserDefaults.standard.data(forKey: "buildings_\(cityId)"),
              let saved = try? JSONDecoder().decode([Building].self, from: data),
              saved.first?.coordinates.isEmpty == false else { return nil }
        return saved
    }

    func loadProgress() {
        totalPoints = UserDefaults.standard.integer(forKey: "totalPoints")
        if let cityId = city?.id,
           let data = UserDefaults.standard.data(forKey: "buildings_\(cityId)"),
           let saved = try? JSONDecoder().decode([Building].self, from: data) {
            for saved in saved {
                if let i = buildings.firstIndex(where: { $0.id == saved.id }) {
                    buildings[i].state = saved.state
                }
            }
        }
    }

    func reset() {
        city = nil
        buildings = []
        totalPoints = 0
        selectedBuilding = nil
    }
}
