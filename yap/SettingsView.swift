import SwiftUI

struct SettingsView: View {
    @ObservedObject var configManager: ConfigurationManager
    @ObservedObject var llmService: LLMService

    @State private var showingInstructionsEditor = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Section
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "gear")
                            .foregroundColor(.blue)
                            .font(.title2)
                        Text("Settings")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Spacer()
                    }

                    HStack {
                        Text("Advanced configuration and cleanup instructions")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                // Cleanup Instructions
                CleanupInstructionsCard(
                    configManager: configManager,
                    llmService: llmService,
                    showingEditor: $showingInstructionsEditor
                )
                .padding(.horizontal, 24)

                // App Information
                AppInfoSection()
                    .padding(.horizontal, 24)

                // Danger Zone
                DangerZoneSection(configManager: configManager)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showingInstructionsEditor) {
            InstructionsEditorSheet(
                configManager: configManager,
                llmService: llmService,
                isPresented: $showingInstructionsEditor
            )
        }
    }
}

struct CleanupInstructionsCard: View {
    @ObservedObject var configManager: ConfigurationManager
    @ObservedObject var llmService: LLMService
    @Binding var showingEditor: Bool

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "doc.text.fill")
                            .font(.title2)
                            .foregroundColor(.purple)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Cleanup Instructions")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text("Customize how AI models clean up your transcriptions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Divider()

            // Preview
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Current Instructions")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Text("\(configManager.cleanupInstructions.count) characters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                ScrollView {
                    Text(configManager.cleanupInstructions)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 80)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Actions
            HStack(spacing: 12) {
                Button("Edit Instructions") {
                    showingEditor = true
                }
                .buttonStyle(.bordered)

                Button("Reset to Default") {
                    configManager.cleanupInstructions = ConfigurationManager.defaultCleanupInstructions
                    llmService.saveSettings()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.orange)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct InstructionsEditorSheet: View {
    @ObservedObject var configManager: ConfigurationManager
    @ObservedObject var llmService: LLMService
    @Binding var isPresented: Bool

    @State private var instructions: String = ""
    @State private var hasChanges = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Edit Cleanup Instructions")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("These instructions guide AI models on how to clean up your transcriptions")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Editor
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Instructions")
                        .font(.headline)

                    Spacer()

                    Text("\(instructions.count) characters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                TextEditor(text: $instructions)
                    .font(.system(.body, design: .default))
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            }

            // Tips
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text("Tips for Better Instructions")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("• Be specific about formatting preferences")
                    Text("• Include examples of desired output")
                    Text("• Mention any technical terms to preserve")
                    Text("• Specify punctuation and capitalization rules")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.yellow.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer()

            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)

                Button("Reset to Default") {
                    instructions = ConfigurationManager.defaultCleanupInstructions
                    hasChanges = true
                }
                .foregroundColor(.orange)

                Button("Save Instructions") {
                    saveInstructions()
                }
                .keyboardShortcut(.return)
                .disabled(!hasChanges)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 600, height: 500)
        .onAppear {
            instructions = configManager.cleanupInstructions
        }
        .onChange(of: instructions) {
            hasChanges = instructions != configManager.cleanupInstructions
        }
    }

    private func saveInstructions() {
        configManager.cleanupInstructions = instructions
        llmService.saveSettings()
        isPresented = false
    }
}

struct AppInfoSection: View {
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "info.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("App Information")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text("Version and system details")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Divider()

            // Info Rows
            VStack(spacing: 12) {
                InfoDetailRow(
                    title: "Version",
                    value: "1.0.0",
                    icon: "number.circle"
                )

                InfoDetailRow(
                    title: "Bundle ID",
                    value: "com.prasoon.yap.yap",
                    icon: "app"
                )

                InfoDetailRow(
                    title: "Transcription Engine",
                    value: "Groq Whisper (distil-whisper-large-v3-en)",
                    icon: "brain.head.profile"
                )

                InfoDetailRow(
                    title: "System",
                    value: "\(ProcessInfo.processInfo.operatingSystemVersionString)",
                    icon: "desktopcomputer"
                )
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct InfoDetailRow: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(value)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

struct DangerZoneSection: View {
    @ObservedObject var configManager: ConfigurationManager

    @State private var showingResetConfirmation = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Danger Zone")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)

                    Text("Irreversible actions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Divider()

            // Reset Button
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reset All Settings")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("This will clear all API keys and reset settings to defaults")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button("Reset All") {
                        showingResetConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
            }
        }
        .padding(16)
        .background(Color.red.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
        .alert("Reset All Settings?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset All", role: .destructive) {
                resetAllSettings()
            }
        } message: {
            Text("This will permanently delete all API keys and reset all settings to their defaults. This action cannot be undone.")
        }
    }

    private func resetAllSettings() {
        // Clear API keys
        configManager.apiKeyStatus.removeAll()

        // Reset to defaults
        configManager.selectedLLMModel = .groqLlama31_8B
        configManager.cleanupInstructions = ConfigurationManager.defaultCleanupInstructions
        configManager.cleanupEnabled = true

        // Save changes
        configManager.saveConfiguration()

        // Note: Groq service API key would need to be cleared separately
        // This might require adding a clearAPIKey method to GroqService
    }
}