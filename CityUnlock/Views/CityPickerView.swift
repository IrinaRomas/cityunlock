import SwiftUI
import CoreLocation

struct CityPickerView: View {
    @EnvironmentObject var gameState: GameState
    @State private var searchText = ""
    @State private var results: [City] = []
    @State private var isSearching = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {

            // Header
            VStack(spacing: 8) {
                Text("🏙")
                    .font(.system(size: 56))
                Text("City Unlock")
                    .font(.system(size: 28, weight: .bold))
                Text("Выберите свой город")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 60)
            .padding(.bottom, 32)

            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Введите название города...", text: $searchText)
                    .autocorrectionDisabled()
                    .onSubmit { search() }
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal, 24)
            .onChange(of: searchText) { _ in
                if searchText.count > 2 { search() }
            }

            // Error
            if let error = error {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }

            // Results
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(results) { city in
                        Button {
                            selectCity(city)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(city.name)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                    Text(city.country)
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                        }
                        Divider()
                            .padding(.leading, 24)
                    }
                }
            }
            .padding(.top, 12)

            Spacer()
        }
    }

    private func search() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        error = nil

        Task {
            do {
                let cities = try await NominatimService.shared.searchCities(query: searchText)
                print("Найдено городов: \(cities.count)")
                await MainActor.run {
                    results = cities
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    self.error = "Ошибка поиска. Проверьте интернет."
                    isSearching = false
                }
            }
        }
    }

    private func tileKey(lat: Double, lon: Double, zoom: Double) -> String {
        "\(Int(lat / zoom))_\(Int(lon / zoom))"
    }

    private func selectCity(_ city: City) {
        gameState.city = city

        // Use cache if available — instant load
        if let cached = gameState.loadCached(for: city.id) {
            gameState.buildings = cached
            gameState.totalPoints = UserDefaults.standard.integer(forKey: "totalPoints")
            return
        }

        gameState.isLoading = true
        gameState.loadingMessage = "Загрузка зданий..."
        gameState.loadedRegions.removeAll()

        Task {
            do {
                // Load only initial viewport (~2km around city center) first
                let lat = city.latitude, lon = city.longitude
                let delta = 0.015
                let initialBbox = "\(lat - delta),\(lon - delta),\(lat + delta),\(lon + delta)"
                let tileKey = tileKey(lat: lat, lon: lon, zoom: 2)
                gameState.loadedRegions.insert(tileKey)

                let initial = try await OverpassService.shared.loadBuildings(bbox: initialBbox)

                await MainActor.run {
                    gameState.buildings = initial
                    gameState.coins = 500
                    gameState.totalPoints = 0
                    gameState.isLoading = false
                }
            } catch {
                await MainActor.run {
                    gameState.isLoading = false
                    gameState.city = nil
                    self.error = "Не удалось загрузить данные города."
                }
            }
        }
    }
}
