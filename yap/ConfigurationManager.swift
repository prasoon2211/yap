import Foundation

class ConfigurationManager: ObservableObject {
    @Published var selectedLLMModel: LLMModel = .groqLlama31_8B
    /// Default cleanup prompt shown to the user. Declared as a static constant so
    /// it can be reused across the code-base (e.g. when the user taps “Reset to Default”).
    static let defaultCleanupInstructions = """
You are a text-cleaning assistant. I will provide you with a transcript from a speech-to-text program. Your task is to clean up the transcript by fixing typos, grammar, punctuation, and formatting while preserving the original meaning.

IMPORTANT INSTRUCTIONS:
1. Respond with ONLY the cleaned-up transcript. Do NOT include any explanations, comments, or additional text.
2. If the transcript is already clean, simply repeat it exactly as it is, without adding any commentary or changes.
3. Do NOT include any introductory or concluding remarks. Only output the cleaned-up transcript.

Here is the transcript:
"""

    /// The user-customisable cleanup instructions. Defaults to
    /// `defaultCleanupInstructions` but can be edited at runtime.
    @Published var cleanupInstructions = defaultCleanupInstructions
    @Published var cleanupEnabled = true
    @Published var apiKeyStatus: [LLMProvider: Bool] = [:]

    private let configFileName = "config.json"

    init() {
        loadConfiguration()
        refreshAPIKeyStatus()
    }

    private func getConfigDirectoryURL() -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        let appDir = appSupport.appendingPathComponent("MinimalTranscribe")

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)

        return appDir
    }

    private func getConfigFileURL() -> URL? {
        return getConfigDirectoryURL()?.appendingPathComponent(configFileName)
    }

    private func loadConfiguration() {
        guard let configURL = getConfigFileURL(),
              FileManager.default.fileExists(atPath: configURL.path) else {
            print("Config file doesn't exist, using defaults")
            return
        }

        do {
            let data = try Data(contentsOf: configURL)
            let config = try JSONDecoder().decode(Configuration.self, from: data)

            selectedLLMModel = LLMModel(rawValue: config.selectedLLMModel) ?? .groqLlama31_8B
            cleanupInstructions = config.cleanupInstructions
            cleanupEnabled = config.cleanupEnabled

            print("Configuration loaded successfully")
        } catch {
            print("Failed to load configuration: \(error)")
        }
    }

    func saveConfiguration() {
        let config = Configuration(
            selectedLLMModel: selectedLLMModel.rawValue,
            cleanupInstructions: cleanupInstructions,
            cleanupEnabled: cleanupEnabled
        )

        guard let configURL = getConfigFileURL() else {
            print("Failed to get config file URL")
            return
        }

        do {
            let data = try JSONEncoder().encode(config)
            try data.write(to: configURL)
            print("Configuration saved successfully")
        } catch {
            print("Failed to save configuration: \(error)")
        }
    }

    // MARK: - API Key Management

    func saveAPIKey(_ key: String, for provider: LLMProvider) -> Bool {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return false }

        let keyFileName = "\(provider.rawValue)_api_key.txt"
        guard let configDir = getConfigDirectoryURL() else { return false }

        let keyFileURL = configDir.appendingPathComponent(keyFileName)

        do {
            try trimmedKey.write(to: keyFileURL, atomically: true, encoding: .utf8)
            print("API key saved for \(provider.rawValue)")
            refreshAPIKeyStatus()
            return true
        } catch {
            print("Failed to save API key for \(provider.rawValue): \(error)")
            return false
        }
    }

    func getAPIKey(for provider: LLMProvider) -> String? {
        let keyFileName = "\(provider.rawValue)_api_key.txt"
        guard let configDir = getConfigDirectoryURL() else { return nil }

        let keyFileURL = configDir.appendingPathComponent(keyFileName)

        do {
            let key = try String(contentsOf: keyFileURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
            return key.isEmpty ? nil : key
        } catch {
            // File doesn't exist or can't be read - this is normal for first run
            return nil
        }
    }

    func hasAPIKey(for provider: LLMProvider) -> Bool {
        return getAPIKey(for: provider) != nil
    }

    func deleteAPIKey(for provider: LLMProvider) -> Bool {
        let keyFileName = "\(provider.rawValue)_api_key.txt"
        guard let configDir = getConfigDirectoryURL() else { return false }

        let keyFileURL = configDir.appendingPathComponent(keyFileName)

        do {
            try FileManager.default.removeItem(at: keyFileURL)
            print("API key deleted for \(provider.rawValue)")
            return true
        } catch {
            print("Failed to delete API key for \(provider.rawValue): \(error)")
            return false
        }
    }

    // MARK: - Provider-specific helpers

    func isProviderConfigured(_ provider: LLMProvider) -> Bool {
        switch provider {
        case .groq:
            // For Groq, we check the existing GroqService
            return true // We'll check this in LLMService
        case .openai, .anthropic, .google:
            return hasAPIKey(for: provider)
        }
    }

    func getProviderDisplayName(_ provider: LLMProvider) -> String {
        switch provider {
        case .openai:
            return "OpenAI"
        case .anthropic:
            return "Anthropic"
        case .google:
            return "Google"
        case .groq:
            return "Groq"
        }
    }

    func refreshAPIKeyStatus() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.apiKeyStatus = [
                .openai: self.hasAPIKey(for: .openai),
                .anthropic: self.hasAPIKey(for: .anthropic),
                .google: self.hasAPIKey(for: .google),
                .groq: true // We'll handle Groq separately in the UI
            ]
        }
    }
}

// MARK: - Configuration Data Structure

private struct Configuration: Codable {
    let selectedLLMModel: String
    let cleanupInstructions: String
    let cleanupEnabled: Bool
}