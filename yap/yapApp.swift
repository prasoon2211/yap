//
//  yapApp.swift
//  yap
//
//  Created by Prasoon Shukla on 13.07.25.
//

import SwiftUI

@main
struct yapApp: App {
    @StateObject private var hotkeyManager = HotkeyManager()
    
    var body: some Scene {
        MenuBarExtra("MinimalTranscribe", systemImage: getMenuBarIcon()) {
            VStack {
                Text("MinimalTranscribe")
                    .font(.headline)
                    .padding()
                
                Text(getStatusText())
                    .font(.caption)
                    .foregroundColor(getStatusColor())
                    .padding(.horizontal)
                
                if !hotkeyManager.groqService.hasValidKey {
                    Divider()
                    
                    VStack(spacing: 8) {
                        Text("API Key Required")
                            .font(.caption)
                            .foregroundColor(.orange)
                        
                        Button("Enter API Key") {
                            showAPIKeyDialog()
                        }
                        
                        Text("Get your key from console.groq.com")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                Divider()
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
                .padding()
            }
        }
        .menuBarExtraStyle(.window)
    }
    
    private func getMenuBarIcon() -> String {
        if hotkeyManager.isRecording {
            return "mic.fill"
        } else if hotkeyManager.isUploading {
            return "arrow.up.circle.fill"
        } else {
            return "mic"
        }
    }
    
    private func getStatusText() -> String {
        if hotkeyManager.isRecording {
            return "Recording..."
        } else if hotkeyManager.isUploading {
            return "Transcribing..."
        } else {
            return "Hold ⇧⌘Space to record"
        }
    }
    
    private func getStatusColor() -> Color {
        if hotkeyManager.isRecording {
            return .red
        } else if hotkeyManager.isUploading {
            return .blue
        } else {
            return .secondary
        }
    }
    
    private func showAPIKeyDialog() {
        let alert = NSAlert()
        alert.messageText = "Enter Groq API Key"
        alert.informativeText = "Your API key will be stored securely in the macOS Keychain."
        alert.alertStyle = .informational
        
        let textField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.placeholderString = "Enter your Groq API key here"
        alert.accessoryView = textField
        
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            let apiKey = textField.stringValue
            if !apiKey.isEmpty {
                if hotkeyManager.groqService.saveAPIKey(apiKey) {
                    print("API key saved successfully")
                } else {
                    showErrorAlert("Failed to save API key")
                }
            }
        }
    }
    
    private func showErrorAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
