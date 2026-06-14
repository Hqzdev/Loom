//
//  LoomApp.swift
//  Loom
//

import SwiftUI

@main
struct LoomApp: App {
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
