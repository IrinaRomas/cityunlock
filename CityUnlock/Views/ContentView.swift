import SwiftUI

struct ContentView: View {
    @EnvironmentObject var gameState: GameState

    var body: some View {
        Group {
            if gameState.isLoading {
                LoadingView()
                    .transition(.opacity)
            } else if gameState.city == nil {
                CityPickerView()
                    .transition(.opacity)
            } else {
                GameView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: gameState.city?.id)
        .animation(.easeInOut(duration: 0.3), value: gameState.isLoading)
    }
}
