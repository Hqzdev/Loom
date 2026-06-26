//
//  TetherApp.swift
//  Tether
//

import SwiftUI

@main
struct TetherApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .background(WindowChromeHider())
        }
        .defaultSize(width: 800, height: 520)
        .windowStyle(.hiddenTitleBar)
        .commands {
            AgentTraceMenuCommands()
        }
    }
}
