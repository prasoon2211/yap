import SwiftUI

struct MainWindow: View {
    @ObservedObject var configManager: ConfigurationManager
    @ObservedObject var hotkeyManager: HotkeyManager
    @ObservedObject var llmService: LLMService
    @ObservedObject var windowManager: WindowManager

    @State private var selectedTab: Tab = .providers

    enum Tab: String, CaseIterable {
        case providers = "Providers"
        case transcription = "Transcription"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .providers: return "key.fill"
            case .transcription: return "mic.fill"
            case .settings: return "gear"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView(hotkeyManager: hotkeyManager)

            // Tab Navigation
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    TabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        action: { selectedTab = tab }
                    )
                }
            }
            .background(Color(NSColor.controlBackgroundColor))

            // Content
            Group {
                switch selectedTab {
                case .providers:
                    ProvidersView(
                        configManager: configManager,
                        hotkeyManager: hotkeyManager
                    )
                case .transcription:
                    TranscriptionView(
                        configManager: configManager,
                        hotkeyManager: hotkeyManager,
                        llmService: llmService
                    )
                case .settings:
                    SettingsView(
                        configManager: configManager,
                        llmService: llmService
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 600, height: 700)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct HeaderView: View {
    @ObservedObject var hotkeyManager: HotkeyManager

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                // App Icon & Title
                HStack(spacing: 12) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "mic.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("YAP")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        Text("Speech-to-Text Assistant")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Status Indicator
                StatusIndicator(hotkeyManager: hotkeyManager)
            }

            // Status Bar
            StatusBar(hotkeyManager: hotkeyManager)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            LinearGradient(
                colors: [Color(NSColor.windowBackgroundColor), Color(NSColor.controlBackgroundColor)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

struct StatusIndicator: View {
    @ObservedObject var hotkeyManager: HotkeyManager

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .animation(.easeInOut(duration: 0.3), value: statusColor)

            Text(statusText)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(statusColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var statusColor: Color {
        if hotkeyManager.isRecording {
            return .red
        } else if hotkeyManager.isUploading {
            return .blue
        } else if hotkeyManager.isCleaningUp {
            return .green
        } else {
            return .gray
        }
    }

    private var statusText: String {
        if hotkeyManager.isRecording {
            return "Recording"
        } else if hotkeyManager.isUploading {
            return "Processing"
        } else if hotkeyManager.isCleaningUp {
            return "Cleaning"
        } else {
            return "Ready"
        }
    }
}

struct StatusBar: View {
    @ObservedObject var hotkeyManager: HotkeyManager

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "keyboard")
                    .foregroundColor(.secondary)
                Text("Press ⇧⌘Space to record")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !hotkeyManager.isRecording && !hotkeyManager.isUploading && !hotkeyManager.isCleaningUp {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("Ready to record")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct TabButton: View {
    let tab: MainWindow.Tab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14, weight: .medium))
                Text(tab.rawValue)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isSelected ? .primary : .secondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                isSelected
                    ? Color(NSColor.selectedControlColor).opacity(0.2)
                    : Color.clear
            )
            .overlay(
                Rectangle()
                    .frame(height: 2)
                    .foregroundColor(isSelected ? .accentColor : .clear)
                    .animation(.easeInOut(duration: 0.2), value: isSelected),
                alignment: .bottom
            )
        }
        .buttonStyle(.plain)
    }
}