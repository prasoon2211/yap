//
//  yapApp.swift
//  yap
//
//  Created by Prasoon Shukla on 13.07.25.
//

import SwiftUI

@main
struct yapApp: App {
    @StateObject private var configManager = ConfigurationManager()
    @StateObject private var hotkeyManager: HotkeyManager
    @StateObject private var llmService: LLMService
    @StateObject private var windowManager = WindowManager()
    @State private var isMainWindowOpen = false

    init() {
        let configManager = ConfigurationManager()
        let hotkeyManager = HotkeyManager(configManager: configManager)
        let llmService = LLMService(configManager: configManager, groqService: hotkeyManager.groqService)

        // Connect the services
        hotkeyManager.setLLMService(llmService)

        _configManager = StateObject(wrappedValue: configManager)
        _hotkeyManager = StateObject(wrappedValue: hotkeyManager)
        _llmService = StateObject(wrappedValue: llmService)
    }

        var body: some Scene {
        MenuBarExtra("YAP", systemImage: getMenuBarIcon()) {
            MenuBarContent(
                windowManager: windowManager,
                statusText: getStatusText()
            )
        }
        .menuBarExtraStyle(.menu)

        // Main Application Window
        Window("YAP", id: "main-window") {
            MainWindow(
                configManager: configManager,
                hotkeyManager: hotkeyManager,
                llmService: llmService,
                windowManager: windowManager
            )
            .onAppear {
                windowManager.windowIsVisible = true
                // Make sure the window appears on top
                DispatchQueue.main.async {
                    if let mainWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == "main-window" }) {
                        mainWindow.level = NSWindow.Level.floating
                        mainWindow.makeKeyAndOrderFront(nil)
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
            }
            .onDisappear {
                windowManager.windowIsVisible = false
                isMainWindowOpen = false
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 600, height: 700)
        .defaultPosition(.center)
    }

    private func getMenuBarIcon() -> String {
        if hotkeyManager.isRecording {
            return "mic.fill"
        } else if hotkeyManager.isUploading {
            return "arrow.up.circle.fill"
        } else if hotkeyManager.isCleaningUp {
            return "sparkles"
        } else {
            return "mic"
        }
    }

    private func getStatusText() -> String {
        if hotkeyManager.isRecording {
            return "🔴 Recording..."
        } else if hotkeyManager.isUploading {
            return "📤 Transcribing..."
        } else if hotkeyManager.isCleaningUp {
            return "✨ Cleaning up..."
        } else {
            return "⌨️ Press ⇧⌘Space to record"
        }
    }

    private func getStatusColor() -> Color {
        if hotkeyManager.isRecording {
            return .red
        } else if hotkeyManager.isUploading {
            return .blue
        } else if hotkeyManager.isCleaningUp {
            return .green
        } else {
            return .primary
        }
    }
}
