import SwiftUI

struct SettingsView: View {
    @ObservedObject var configManager: ConfigurationManager
    @ObservedObject var llmService: LLMService



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
                        Text("Advanced configuration and app information")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)



                // App Information
                AppInfoSection()
                    .padding(.horizontal, 24)

                // Danger Zone
                DangerZoneSection(configManager: configManager)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
            }
        }

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