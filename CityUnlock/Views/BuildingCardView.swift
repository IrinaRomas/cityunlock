import SwiftUI

struct BuildingCardView: View {
    let building: Building
    @EnvironmentObject var gameState: GameState
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 0) {

            // Handle bar
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 12)

            HStack(alignment: .top, spacing: 14) {

                // Icon
                Text(building.type.emoji)
                    .font(.system(size: 38))
                    .frame(width: 56, height: 56)
                    .background(Color(.systemGray6))
                    .cornerRadius(14)

                VStack(alignment: .leading, spacing: 4) {
                    Text(building.displayName)
                        .font(.system(size: 16, weight: .semibold))
                    Text(building.type.displayName)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Label("\(Int(building.areaM2)) м²", systemImage: "square")
                        Label("\(building.levels) эт.", systemImage: "building.2")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
                }

                Spacer()

                // State badge
                stateBadge
            }
            .padding(.horizontal, 20)

            Divider()
                .padding(.vertical, 14)

            // Stats row
            HStack(spacing: 0) {
                statCell(value: "+\(building.earnedPoints) XP", label: "опыт", color: .green)
                Divider().frame(height: 36)
                statCell(value: "\(building.unlockCost) 💰", label: "стоимость", color: .orange)
                Divider().frame(height: 36)
                statCell(value: "Ур. \(building.requiredLevel)", label: "требуется", color: .blue)
            }
            .padding(.horizontal, 20)

            // Passive income row
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 13))
                    .foregroundColor(.green)
                Text("Доход: +\(building.type.incomePerHour) 💰/ч")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.green)
                if building.state == .unlocked {
                    Text("· уже приносит")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color.green.opacity(0.08))
            .cornerRadius(10)
            .padding(.horizontal, 20)

            // Action button
            actionButton
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.12), radius: 20, y: -4)
    }

    @ViewBuilder
    private var stateBadge: some View {
        switch building.state {
        case .locked:
            Text("🔒 Закрыто")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray5))
                .cornerRadius(8)
        case .constructing:
            Text("🏗 Строится")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(8)
        case .unlocked:
            Text("✅ Открыто")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.12))
                .cornerRadius(8)
        }
    }

    private func statCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var actionButton: some View {
        switch building.state {
        case .unlocked:
            EmptyView()

        case .constructing:
            HStack {
                ProgressView()
                    .scaleEffect(0.9)
                Text("Идёт строительство...")
                    .font(.system(size: 15))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(.systemGray5))
            .cornerRadius(14)

        case .locked:
            if gameState.currentLevel.level < building.requiredLevel {
                // Level requirement not met
                VStack(spacing: 4) {
                    Text("Доступно с уровня \(building.requiredLevel)")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("Ваш уровень: \(gameState.currentLevel.level)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(.systemGray5))
                .cornerRadius(14)

            } else if gameState.coins < building.unlockCost {
                // Not enough coins
                VStack(spacing: 4) {
                    Text("Не хватает \(building.unlockCost - gameState.coins) 💰")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("У вас: \(gameState.coins) / \(building.unlockCost)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(.systemGray5))
                .cornerRadius(14)

            } else {
                // Can unlock
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        gameState.unlock(building: building)
                    }
                } label: {
                    HStack {
                        Image(systemName: "lock.open.fill")
                        Text("Разблокировать · \(building.unlockCost) 💰")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }
                .scaleEffect(isAnimating ? 0.97 : 1.0)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever()) {
                        isAnimating = true
                    }
                }
            }
        }
    }
}
