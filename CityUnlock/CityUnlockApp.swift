//
//  CityUnlockApp.swift
//  CityUnlock
//
//  Created by Ирина Ромась on 26.06.2026.
//

import SwiftUI

@main
struct CityUnlockApp: App {
    @StateObject private var gameState = GameState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gameState)
                .onAppear {
                    gameState.restoreSession()
                }
        }
    }
}
