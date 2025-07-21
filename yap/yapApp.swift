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
        MenuBarExtra("MinimalTranscribe", systemImage: getMenuBarIcon()) {
            VStack {
                Text("MinimalTranscribe")
                    .font(.headline)
                    .padding()
                
                Text(getStatusText())
                    .font(.caption)
                    .foregroundColor(getStatusColor())
                    .padding(.horizontal)
                
                // Cleanup Settings Section
                if hotkeyManager.groqService.hasValidKey {
                    Divider()
                    
                    VStack(spacing: 8) {
                        Toggle("Enable Cleanup", isOn: $configManager.cleanupEnabled)
                            .font(.caption)
                        
                        if configManager.cleanupEnabled {
                            HStack {
                                Text("Model:")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Picker("", selection: $configManager.selectedLLMModel) {
                                    ForEach(LLMModel.allCases, id: \.self) { model in
                                        HStack {
                                            Text(model.rawValue)
                                            Spacer()
                                            if isModelConfigured(model) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.green)
                                                    .font(.caption2)
                                            } else {
                                                Image(systemName: "exclamationmark.circle.fill")
                                                    .foregroundColor(.orange)
                                                    .font(.caption2)
                                            }
                                        }
                                        .tag(model)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .font(.caption2)
                            }
                            
                            // Show API key status for all providers
                            VStack(spacing: 4) {
                                ForEach([LLMProvider.openai, .anthropic, .google, .groq], id: \.self) { provider in
                                    HStack {
                                        Text(configManager.getProviderDisplayName(provider))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        if isProviderConfigured(provider) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "key.fill")
                                                    .foregroundColor(.green)
                                                Text("✓")
                                                    .foregroundColor(.green)
                                            }
                                            .font(.caption2)
                                        } else {
                                            Button("Add Key") {
                                                showAPIKeyDialog(for: provider)
                                            }
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                        }
                                    }
                                }
                            }
                            .padding(.top, 4)
                            
                            // Warning for unconfigured selected model
                            if !isModelConfigured(configManager.selectedLLMModel) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("Selected model needs API key")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
                                .padding(.top, 2)
                            }
                            
                            Button("Edit Instructions") {
                                showInstructionsDialog()
                            }
                            .font(.caption2)
                        }
                    }
                    .padding(.horizontal)
                    .onChange(of: configManager.selectedLLMModel) {
                        llmService.saveSettings()
                    }
                    .onChange(of: configManager.cleanupEnabled) {
                        llmService.saveSettings()
                    }
                }
                
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
        } else if hotkeyManager.isCleaningUp {
            return "Cleaning up..."
        } else {
            return "Hold ⇧⌘Space to record"
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
            return .secondary
        }
    }
    
    private func needsAPIKey(for provider: LLMProvider) -> Bool {
        switch provider {
        case .groq:
            return !hotkeyManager.groqService.hasValidKey
        case .openai, .anthropic, .google:
            return !configManager.hasAPIKey(for: provider)
        }
    }
    
    private func isProviderConfigured(_ provider: LLMProvider) -> Bool {
        switch provider {
        case .groq:
            return hotkeyManager.groqService.hasValidKey
        case .openai, .anthropic, .google:
            return configManager.apiKeyStatus[provider] ?? false
        }
    }
    
    private func isModelConfigured(_ model: LLMModel) -> Bool {
        return isProviderConfigured(model.provider)
    }
    
    private func showAPIKeyDialog() {
        showAPIKeyDialog(for: .groq)
    }
    
    private func showAPIKeyDialog(for provider: LLMProvider) {
        let alert = NSAlert()
        let providerName = configManager.getProviderDisplayName(provider)
        alert.messageText = "Enter \(providerName) API Key"
        alert.informativeText = "Your API key will be stored securely on your device."
        alert.alertStyle = .informational
        
        let textField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.placeholderString = "Enter your \(providerName) API key here"
        alert.accessoryView = textField
        
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            let apiKey = textField.stringValue
            if !apiKey.isEmpty {
                var success = false
                
                switch provider {
                case .groq:
                    success = hotkeyManager.groqService.saveAPIKey(apiKey)
                case .openai, .anthropic, .google:
                    success = configManager.saveAPIKey(apiKey, for: provider)
                }
                
                if success {
                    print("\(providerName) API key saved successfully")
                } else {
                    showErrorAlert("Failed to save \(providerName) API key")
                }
            }
        }
    }
    
    private func showInstructionsDialog() {
        let alert = NSAlert()
        alert.messageText = "Edit Cleanup Instructions"
        alert.informativeText = "These instructions will be sent to the LLM to clean up your transcription."
        alert.alertStyle = .informational
        
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 100))
        textView.string = configManager.cleanupInstructions
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 100))
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        
        alert.accessoryView = scrollView
        
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Reset to Default")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            let instructions = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !instructions.isEmpty {
                configManager.cleanupInstructions = instructions
                configManager.saveConfiguration()
                print("Cleanup instructions updated")
            }
        } else if response == .alertThirdButtonReturn {
            configManager.cleanupInstructions = "Clean up this transcript by fixing typos, grammar, and formatting while preserving the original meaning."
            configManager.saveConfiguration()
            print("Cleanup instructions reset to default")
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
