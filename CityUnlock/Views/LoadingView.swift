import SwiftUI

struct LoadingView: View {
    @EnvironmentObject var gameState: GameState
    @State private var dots = ""
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("🏙")
                .font(.system(size: 64))

            VStack(spacing: 8) {
                Text(gameState.loadingMessage + dots)
                    .font(.system(size: 16, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)

                Text(gameState.city?.displayName ?? "")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 40)

            ProgressView()
                .scaleEffect(1.4)
                .padding(.top, 8)

            Spacer()

            Text("Данные предоставлены OpenStreetMap")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.bottom, 32)
        }
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                dots = dots.count < 3 ? dots + "." : ""
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
}
