import SwiftUI

struct HUDView: View {
    @EnvironmentObject var gameState: GameState

    var body: some View {
        VStack {
            // Top bar
            HStack(spacing: 10) {

                // Points
                HStack(spacing: 5) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 13))
                    Text("\(gameState.totalPoints) оч.")
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial)
                .cornerRadius(20)

                Spacer()

                // Level + progress
                VStack(alignment: .trailing, spacing: 3) {
                    HStack(spacing: 5) {
                        Text("Ур. \(gameState.currentLevel.level)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.blue)
                        Text(gameState.currentLevel.title)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    if let next = gameState.nextLevel {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: 5)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.blue)
                                    .frame(width: geo.size.width * gameState.progressToNextLevel,
                                           height: 5)
                            }
                        }
                        .frame(width: 80, height: 5)

                        Text("до ур. \(next.level): \(next.pointsRequired - gameState.totalPoints) оч.")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Максимальный уровень!")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Spacer()
        }
    }
}
