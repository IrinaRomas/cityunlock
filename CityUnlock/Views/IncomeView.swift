import SwiftUI

struct IncomeView: View {
    @EnvironmentObject var gameState: GameState
    @State private var animating = false

    var body: some View {
        VStack(spacing: 16) {
            Text("💰")
                .font(.system(size: 56))
                .scaleEffect(animating ? 1.15 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: animating)

            Text("Пока тебя не было")
                .font(.headline)
                .foregroundColor(.primary)

            Text("город заработал")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("+\(gameState.pendingIncome) ⭐")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.yellow)

            Text("Текущий доход: \(gameState.totalIncomePerHour) ⭐/час")
                .font(.caption)
                .foregroundColor(.secondary)

            Button {
                withAnimation(.spring(response: 0.3)) {
                    gameState.collectIncome()
                }
            } label: {
                Text("Собрать")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.green)
                    .cornerRadius(14)
            }
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 32)
        .onAppear { animating = true }
    }
}

struct IncomeOverlay: View {
    @EnvironmentObject var gameState: GameState

    var body: some View {
        if gameState.pendingIncome > 0 {
            ZStack {
                Color.black.opacity(0.4).ignoresSafeArea()
                IncomeView()
            }
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }
}
