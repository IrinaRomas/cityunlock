import SwiftUI
import SpriteKit

struct CitySceneView: UIViewRepresentable {
    @EnvironmentObject var gameState: GameState

    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.ignoresSiblingOrder = true

//        let scene = CityScene()
        let scene = CityScene(size: view.bounds.size)
        scene.scaleMode = .resizeFill
        scene.onBuildingTapped = { building in
            DispatchQueue.main.async {
                gameState.selectedBuilding = building
            }
        }

        view.presentScene(scene)
        context.coordinator.scene = scene

        // ВАЖНО: сначала configure, потом buildings
        if let city = gameState.city {
            scene.configure(with: city)
        }
        let buildings = gameState.buildings
        let roads = gameState.roads
        scene.buildings = buildings
        scene.roads = roads

        return view
    }

    func updateUIView(_ uiView: SKView, context: Context) {
        guard let scene = context.coordinator.scene else { return }
        let roads = gameState.roads
        let buildings = gameState.buildings
        scene.roads = roads
        scene.buildings = buildings
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var scene: CityScene?
    }
}
