import SwiftUI

struct TranscriptionView: View {
    @ObservedObject var configManager: ConfigurationManager
    @ObservedObject var hotkeyManager: HotkeyManager
    @ObservedObject var llmService: LLMService

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Section
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "mic.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                        Text("Transcription Settings")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Spacer()
                    }

                    HStack {
                        Text("Configure speech-to-text and text cleanup settings")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                // Primary Transcription
                TranscriptionCard(
                    hotkeyManager: hotkeyManager
                )
                .padding(.horizontal, 24)

                // Text Cleanup Section
                CleanupSection(
                    configManager: configManager,
                    hotkeyManager: hotkeyManager,
                    llmService: llmService
                )
                .padding(.horizontal, 24)

                // Cleanup Instructions
                CleanupInstructionsSection(
                    configManager: configManager,
                    llmService: llmService
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }
}

struct TranscriptionCard: View {
    @ObservedObject var hotkeyManager: HotkeyManager

    var body: some View {
        VStack(spacing: 16) {
            headerSection
            Divider()
            settingsSection
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(hotkeyManager.groqService.hasValidKey ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    private var headerSection: some View {
        HStack {
            transcriptionIcon
            transcriptionTitle
            Spacer()
            statusBadge
        }
    }

    private var transcriptionIcon: some View {
        Circle()
            .fill(Color.blue.opacity(0.2))
            .frame(width: 40, height: 40)
            .overlay(
                Image(systemName: "waveform")
                    .font(.title2)
                    .foregroundColor(.blue)
            )
    }

    private var transcriptionTitle: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Speech-to-Text")
                .font(.headline)
                .fontWeight(.semibold)

            Text("Powered by Groq Whisper • Ultra-fast transcription")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(hotkeyManager.groqService.hasValidKey ? Color.green : Color.orange)
                .frame(width: 8, height: 8)

            Text(hotkeyManager.groqService.hasValidKey ? "Ready" : "Needs Setup")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(hotkeyManager.groqService.hasValidKey ? Color.green : Color.orange)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background((hotkeyManager.groqService.hasValidKey ? Color.green : Color.orange).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var settingsSection: some View {
        VStack(spacing: 12) {
            HStack {
                modelInfo
                Spacer()
                hotkeyInfo
            }
        }
    }

    private var modelInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Model")
                .font(.subheadline)
                .fontWeight(.medium)

            Text("distil-whisper-large-v3-en")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(Color.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    private var hotkeyInfo: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("Hotkey")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack(spacing: 4) {
                Text("⇧")
                Text("⌘")
                Text("Space")
            }
            .font(.system(.caption, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}

struct PerformanceMetric: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
        }
    }
}

struct CleanupSection: View {
    @ObservedObject var configManager: ConfigurationManager
    @ObservedObject var hotkeyManager: HotkeyManager
    @ObservedObject var llmService: LLMService

    @State private var showingModelPicker = false

    var body: some View {
        VStack(spacing: 16) {
            // Header with Toggle
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)

                        Text("Text Cleanup")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }

                    Text("AI-powered grammar and formatting corrections")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("", isOn: $configManager.cleanupEnabled)
                    .scaleEffect(0.8)
            }

            if configManager.cleanupEnabled {
                Divider()

                // Model Selection
                VStack(spacing: 12) {
                    // Selected Model Display
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cleanup Model")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Button(action: { showingModelPicker = true }) {
                                HStack {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(modelColor.opacity(0.2))
                                            .frame(width: 24, height: 24)
                                            .overlay(
                                                Image(systemName: modelIcon)
                                                    .font(.caption)
                                                    .foregroundColor(modelColor)
                                            )

                                        Text(configManager.selectedLLMModel.rawValue)
                                            .font(.subheadline)
                                            .fontWeight(.medium)

                                        if !isModelConfigured {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(.orange)
                                                .font(.caption)
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(NSColor.controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()

                        // Model Status
                        HStack(spacing: 6) {
                            Circle()
                                .fill(isModelConfigured ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)

                            Text(isModelConfigured ? "Ready" : "Setup Required")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(isModelConfigured ? Color.green : Color.orange)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((isModelConfigured ? Color.green : Color.orange).opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    if !isModelConfigured {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.orange)
                            Text("This model requires an API key. Configure it in the Providers tab.")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: $showingModelPicker) {
            ModelPickerSheet(
                configManager: configManager,
                hotkeyManager: hotkeyManager,
                isPresented: $showingModelPicker
            )
        }
        .onChange(of: configManager.selectedLLMModel) {
            llmService.saveSettings()
        }
        .onChange(of: configManager.cleanupEnabled) {
            llmService.saveSettings()
        }
    }

    private var modelColor: Color {
        switch configManager.selectedLLMModel.provider {
        case .groq: return .blue
        case .openai: return .green
        case .anthropic: return .orange
        case .google: return .red
        }
    }

    private var modelIcon: String {
        switch configManager.selectedLLMModel.provider {
        case .groq: return "bolt.fill"
        case .openai: return "brain.head.profile"
        case .anthropic: return "atom"
        case .google: return "globe"
        }
    }

    private var isModelConfigured: Bool {
        switch configManager.selectedLLMModel.provider {
        case .groq:
            return hotkeyManager.groqService.hasValidKey
        case .openai, .anthropic, .google:
            return configManager.apiKeyStatus[configManager.selectedLLMModel.provider] ?? false
        }
    }
}

struct ModelPickerSheet: View {
    @ObservedObject var configManager: ConfigurationManager
    @ObservedObject var hotkeyManager: HotkeyManager
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Choose Cleanup Model")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button("Done") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }

            // Models List
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(LLMModel.allCases, id: \.self) { model in
                        ModelRow(
                            model: model,
                            isSelected: model == configManager.selectedLLMModel,
                            isConfigured: isModelConfigured(model),
                            onSelect: { configManager.selectedLLMModel = model }
                        )
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 500, height: 400)
    }

    private func isModelConfigured(_ model: LLMModel) -> Bool {
        switch model.provider {
        case .groq:
            return hotkeyManager.groqService.hasValidKey
        case .openai, .anthropic, .google:
            return configManager.apiKeyStatus[model.provider] ?? false
        }
    }
}

struct ModelRow: View {
    let model: LLMModel
    let isSelected: Bool
    let isConfigured: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Provider Icon
                Circle()
                    .fill(providerColor.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: providerIcon)
                            .font(.subheadline)
                            .foregroundColor(providerColor)
                    )

                // Model Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text(providerDisplayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Status and Selection
                HStack(spacing: 8) {
                    if !isConfigured {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                isSelected
                    ? Color.blue.opacity(0.1)
                    : Color(NSColor.controlBackgroundColor)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? .blue : .clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var providerColor: Color {
        switch model.provider {
        case .groq: return .blue
        case .openai: return .green
        case .anthropic: return .orange
        case .google: return .red
        }
    }

    private var providerIcon: String {
        switch model.provider {
        case .groq: return "bolt.fill"
        case .openai: return "brain.head.profile"
        case .anthropic: return "atom"
        case .google: return "globe"
        }
    }

    private var providerDisplayName: String {
        switch model.provider {
        case .groq: return "Groq"
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .google: return "Google"
        }
    }
}

struct CleanupInstructionsSection: View {
    @ObservedObject var configManager: ConfigurationManager
    @ObservedObject var llmService: LLMService
    @State private var showingInstructionsEditor = false

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
                    showingInstructionsEditor = true
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
        .sheet(isPresented: $showingInstructionsEditor) {
            InstructionsEditorSheet(
                configManager: configManager,
                llmService: llmService,
                isPresented: $showingInstructionsEditor
            )
        }
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