import SwiftUI

struct ProvidersView: View {
    @ObservedObject var configManager: ConfigurationManager
    @ObservedObject var hotkeyManager: HotkeyManager

    @State private var showingAPIKeyDialog = false
    @State private var selectedProvider: LLMProvider?

    private let providers: [LLMProvider] = [.groq, .openai, .anthropic, .google]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Section
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                        Text("Model Providers")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Spacer()
                    }

                    HStack {
                        Text("Manage your API keys for different language model providers")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                // Providers Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(providers, id: \.self) { provider in
                        ProviderCard(
                            provider: provider,
                            configManager: configManager,
                            hotkeyManager: hotkeyManager,
                            onAddKey: { selectedProvider = provider; showingAPIKeyDialog = true }
                        )
                    }
                }
                .padding(.horizontal, 24)

                // Info Section
                InfoSection()
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showingAPIKeyDialog) {
            if let provider = selectedProvider {
                APIKeySheet(
                    provider: provider,
                    configManager: configManager,
                    hotkeyManager: hotkeyManager,
                    isPresented: $showingAPIKeyDialog
                )
            }
        }
    }
}

struct ProviderCard: View {
    let provider: LLMProvider
    @ObservedObject var configManager: ConfigurationManager
    @ObservedObject var hotkeyManager: HotkeyManager
    let onAddKey: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Provider Header
            HStack(spacing: 12) {
                Circle()
                    .fill(providerColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: providerIcon)
                            .font(.title2)
                            .foregroundColor(providerColor)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(providerDisplayName)
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text(providerDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }

            // Status Section
            VStack(spacing: 8) {
                HStack {
                    StatusBadge(isConfigured: isProviderConfigured)
                    Spacer()
                }

                if isProviderConfigured {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("API key configured")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    Button(action: onAddKey) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add API Key")
                                .fontWeight(.medium)
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(providerColor)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isProviderConfigured ? .green.opacity(0.3) : .clear, lineWidth: 1)
        )
    }

    private var providerColor: Color {
        switch provider {
        case .groq: return .blue
        case .openai: return .green
        case .anthropic: return .orange
        case .google: return .red
        }
    }

    private var providerIcon: String {
        switch provider {
        case .groq: return "bolt.fill"
        case .openai: return "brain.head.profile"
        case .anthropic: return "atom"
        case .google: return "globe"
        }
    }

    private var providerDisplayName: String {
        configManager.getProviderDisplayName(provider)
    }

    private var providerDescription: String {
        switch provider {
        case .groq: return "Ultra-fast inference • Free tier available"
        case .openai: return "GPT models • Industry standard"
        case .anthropic: return "Claude models • Safety focused"
        case .google: return "Gemini models • Multimodal AI"
        }
    }

    private var isProviderConfigured: Bool {
        switch provider {
        case .groq:
            return hotkeyManager.groqService.hasValidKey
        case .openai, .anthropic, .google:
            return configManager.apiKeyStatus[provider] ?? false
        }
    }
}

struct StatusBadge: View {
    let isConfigured: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isConfigured ? Color.green : Color.orange)
                .frame(width: 6, height: 6)

            Text(isConfigured ? "Connected" : "Not configured")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(isConfigured ? Color.green : Color.orange)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background((isConfigured ? Color.green : Color.orange).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct InfoSection: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("About API Keys")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                InfoRow(
                    icon: "lock.fill",
                    title: "Secure Storage",
                    description: "All API keys are stored securely on your device"
                )

                InfoRow(
                    icon: "network",
                    title: "Direct Connection",
                    description: "Your keys connect directly to providers, no intermediary servers"
                )

                InfoRow(
                    icon: "dollarsign.circle",
                    title: "Usage Billing",
                    description: "You'll be billed directly by each provider based on usage"
                )
            }
        }
        .padding(16)
        .background(Color.blue.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

struct APIKeySheet: View {
    let provider: LLMProvider
    @ObservedObject var configManager: ConfigurationManager
    @ObservedObject var hotkeyManager: HotkeyManager
    @Binding var isPresented: Bool

    @State private var apiKey: String = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Circle()
                    .fill(providerColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: providerIcon)
                            .font(.title)
                            .foregroundColor(providerColor)
                    )

                VStack(alignment: .leading) {
                    Text("Add \(providerDisplayName) API Key")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Enter your API key to enable \(providerDisplayName) models")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // API Key Input
            VStack(alignment: .leading, spacing: 8) {
                Text("API Key")
                    .font(.headline)

                SecureField("Enter your API key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                Text("Your API key is stored securely on your device and never shared.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Get Key Link
            HStack {
                Image(systemName: "link.circle.fill")
                    .foregroundColor(.blue)

                Text("Get your API key from:")
                    .font(.subheadline)

                Button(providerURL) {
                    NSWorkspace.shared.open(URL(string: providerURL)!)
                }
                .font(.subheadline)
                .foregroundColor(.blue)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.blue.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer()

            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)

                Button("Save API Key") {
                    saveAPIKey()
                }
                .keyboardShortcut(.return)
                .disabled(apiKey.isEmpty || isLoading)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 500, height: 300)
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private func saveAPIKey() {
        isLoading = true

        var success = false

        switch provider {
        case .groq:
            success = hotkeyManager.groqService.saveAPIKey(apiKey)
        case .openai, .anthropic, .google:
            success = configManager.saveAPIKey(apiKey, for: provider)
        }

        isLoading = false

        if success {
            isPresented = false
        } else {
            errorMessage = "Failed to save API key. Please try again."
            showError = true
        }
    }

    private var providerColor: Color {
        switch provider {
        case .groq: return .blue
        case .openai: return .green
        case .anthropic: return .orange
        case .google: return .red
        }
    }

    private var providerIcon: String {
        switch provider {
        case .groq: return "bolt.fill"
        case .openai: return "brain.head.profile"
        case .anthropic: return "atom"
        case .google: return "globe"
        }
    }

    private var providerDisplayName: String {
        configManager.getProviderDisplayName(provider)
    }

    private var providerURL: String {
        switch provider {
        case .groq: return "https://console.groq.com"
        case .openai: return "https://platform.openai.com"
        case .anthropic: return "https://console.anthropic.com"
        case .google: return "https://console.cloud.google.com"
        }
    }
}