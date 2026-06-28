import SwiftUI
import MapKit

struct GameView: View {
    @EnvironmentObject var gameState: GameState

    var body: some View {
        ZStack {
            if let city = gameState.city {
                CityMapView(
                    city: city,
                    buildings: gameState.buildings,
                    totalPoints: gameState.totalPoints,
                    playerLevel: gameState.currentLevel.level,
                    onTap: { building in
                        DispatchQueue.main.async {
                            gameState.selectedBuilding = building
                        }
                    },
                    onRegionChange: { region in
                        loadIfNeeded(region: region)
                    }
                )
                .ignoresSafeArea()
            }

            HUDView()
                .ignoresSafeArea(edges: .top)

            if let building = gameState.selectedBuilding {
                VStack {
                    Spacer()
                    BuildingCardView(building: building)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .ignoresSafeArea(edges: .bottom)
                .background(
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                gameState.selectedBuilding = nil
                            }
                        }
                )
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.35), value: gameState.selectedBuilding?.id)
        .overlay {
            IncomeOverlay()
                .animation(.spring(response: 0.4), value: gameState.pendingIncome > 0)
        }
        .onAppear {
            gameState.calculateOfflineIncome()
        }
    }

    private var loadTask: Task<Void, Never>? { nil } // stored in class below

    private func loadIfNeeded(region: MKCoordinateRegion) {
        let center = region.center
        let tileKey = "\(Int(center.latitude / 0.05))_\(Int(center.longitude / 0.05))"
        guard !gameState.loadedRegions.contains(tileKey) else { return }
        gameState.loadedRegions.insert(tileKey)

        // bbox = full tile (0.05°), not just visible area — avoids re-loading on small pans
        let tileSize = 0.05
        let tileLat = Double(Int(center.latitude / tileSize)) * tileSize
        let tileLon = Double(Int(center.longitude / tileSize)) * tileSize
        let bbox = "\(tileLat),\(tileLon),\(tileLat + tileSize),\(tileLon + tileSize)"

        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
            guard !Task.isCancelled else { return }
            guard let new = try? await OverpassService.shared.loadBuildings(bbox: bbox) else { return }
            await MainActor.run { gameState.mergeBuildings(new) }
        }
    }
}
