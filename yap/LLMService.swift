import Foundation

enum LLMModel: String, CaseIterable {
    case openaiGPT41Mini = "OpenAI: GPT-4.1 mini"
    case anthropicHaiku35 = "Anthropic: Claude 3.5 Haiku"
    case googleGemini25Flash = "Google: Gemini 2.5 Flash"
    case googleGemini25FlashLite = "Google: Gemini 2.5 Flash Lite"
    case groqLlama31_8B = "Groq: Llama 3.1 8B Instant"
    case groqLlama3_8B = "Groq: Llama 3 8B"
    
    var provider: LLMProvider {
        switch self {
        case .openaiGPT41Mini:
            return .openai
        case .anthropicHaiku35:
            return .anthropic
        case .googleGemini25Flash, .googleGemini25FlashLite:
            return .google
        case .groqLlama31_8B, .groqLlama3_8B:
            return .groq
        }
    }
    
    var modelName: String {
        switch self {
        case .openaiGPT41Mini:
            return "gpt-4.1-mini"
        case .anthropicHaiku35:
            return "claude-3-5-haiku-20241022"
        case .googleGemini25Flash:
            return "gemini-2.5-flash"
        case .googleGemini25FlashLite:
            return "gemini-2.5-flash-lite-preview-06-17"
        case .groqLlama31_8B:
            return "llama-3.1-8b-instant"
        case .groqLlama3_8B:
            return "llama3-8b-8192"
        }
    }
}

enum LLMProvider: String {
    case openai = "openai"
    case anthropic = "anthropic"
    case google = "google"
    case groq = "groq"
    
    var baseURL: String {
        switch self {
        case .openai:
            return "https://api.openai.com/v1/chat/completions"
        case .anthropic:
            return "https://api.anthropic.com/v1/messages"
        case .google:
            return "https://generativelanguage.googleapis.com/v1beta/models"
        case .groq:
            return "https://api.groq.com/openai/v1/chat/completions"
        }
    }
}

class LLMService: ObservableObject {
    var selectedModel: LLMModel {
        configManager.selectedLLMModel
    }
    
    var cleanupInstructions: String {
        get { configManager.cleanupInstructions }
        set { configManager.cleanupInstructions = newValue }
    }

    private let configManager: ConfigurationManager
    private let groqService: GroqService
    
    init(configManager: ConfigurationManager, groqService: GroqService) {
        self.configManager = configManager
        self.groqService = groqService
    }
    
    func saveSettings() {
        configManager.saveConfiguration()
    }
    
    func cleanupText(_ transcript: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard !transcript.isEmpty else {
            completion(.failure(LLMError.emptyTranscript))
            return
        }
        
        switch selectedModel.provider {
        case .openai:
            cleanupWithOpenAI(transcript, completion: completion)
        case .anthropic:
            cleanupWithAnthropic(transcript, completion: completion)
        case .google:
            cleanupWithGoogle(transcript, completion: completion)
        case .groq:
            cleanupWithGroq(transcript, completion: completion)
        }
    }
    
    private func cleanupWithOpenAI(_ transcript: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let apiKey = configManager.getAPIKey(for: .openai) else {
            completion(.failure(LLMError.noAPIKey(.openai)))
            return
        }
        
        let payload = [
            "model": selectedModel.modelName,
            "messages": [
                [
                    "role": "user",
                    "content": "\(cleanupInstructions)\n\nTranscript: \(transcript)"
                ]
            ],
            "max_tokens": 1000,
            "temperature": 0.1
        ] as [String: Any]
        
        makeRequest(to: selectedModel.provider.baseURL, 
                   headers: ["Authorization": "Bearer \(apiKey)", "Content-Type": "application/json"],
                   payload: payload) { result in
            switch result {
            case .success(let data):
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    completion(.success(content.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else {
                    completion(.failure(LLMError.invalidResponse))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func cleanupWithAnthropic(_ transcript: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let apiKey = configManager.getAPIKey(for: .anthropic) else {
            completion(.failure(LLMError.noAPIKey(.anthropic)))
            return
        }
        
        let payload = [
            "model": selectedModel.modelName,
            "max_tokens": 1000,
            "messages": [
                [
                    "role": "user",
                    "content": "\(cleanupInstructions)\n\nTranscript: \(transcript)"
                ]
            ]
        ] as [String: Any]
        
        makeRequest(to: selectedModel.provider.baseURL,
                   headers: [
                    "x-api-key": apiKey,
                    "Content-Type": "application/json",
                    "anthropic-version": "2023-06-01"
                   ],
                   payload: payload) { result in
            switch result {
            case .success(let data):
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let content = json["content"] as? [[String: Any]],
                   let firstContent = content.first,
                   let text = firstContent["text"] as? String {
                    completion(.success(text.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else {
                    completion(.failure(LLMError.invalidResponse))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func cleanupWithGoogle(_ transcript: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let apiKey = configManager.getAPIKey(for: .google) else {
            completion(.failure(LLMError.noAPIKey(.google)))
            return
        }
        
        let url = "\(selectedModel.provider.baseURL)/\(selectedModel.modelName):generateContent?key=\(apiKey)"
        
        let payload = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": "\(cleanupInstructions)\n\nTranscript: \(transcript)"
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.1,
                "maxOutputTokens": 1000
            ]
        ] as [String: Any]
        
        makeRequest(to: url,
                   headers: ["Content-Type": "application/json"],
                   payload: payload) { result in
            switch result {
            case .success(let data):
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let candidates = json["candidates"] as? [[String: Any]],
                   let firstCandidate = candidates.first,
                   let content = firstCandidate["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let firstPart = parts.first,
                   let text = firstPart["text"] as? String {
                    completion(.success(text.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else {
                    completion(.failure(LLMError.invalidResponse))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func cleanupWithGroq(_ transcript: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard groqService.hasValidKey else {
            completion(.failure(LLMError.noAPIKey(.groq)))
            return
        }
        
        // Get the API key from GroqService via reflection or create a method
        // For now, we'll create a custom method that reuses GroqService internal logic
        makeGroqRequest(transcript: transcript, completion: completion)
    }
    
    private func makeGroqRequest(transcript: String, completion: @escaping (Result<String, Error>) -> Void) {
        let payload = [
            "model": selectedModel.modelName,
            "messages": [
                [
                    "role": "user",
                    "content": "\(cleanupInstructions)\n\nTranscript: \(transcript)"
                ]
            ],
            "max_tokens": 1000,
            "temperature": 0.1
        ] as [String: Any]
        
        // We need to access the Groq API key - let's modify GroqService to expose it
        makeGroqAPICall(payload: payload, completion: completion)
    }
    
    private func makeGroqAPICall(payload: [String: Any], completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: selectedModel.provider.baseURL) else {
            completion(.failure(LLMError.invalidURL))
            return
        }
        
        // We'll need to get the API key from GroqService
        // For now, let's try to get it from the config file directly
        var apiKey: String?
        
        // Try to get API key from environment variable first
        if let envKey = ProcessInfo.processInfo.environment["GROQ_API_KEY"] {
            apiKey = envKey
        } else {
            // Try to load from app's config file (same logic as GroqService)
            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            let keyFile = homeDir.appendingPathComponent(".minimaltranscribe_key")
            
            if let keyFromFile = try? String(contentsOf: keyFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
               !keyFromFile.isEmpty {
                apiKey = keyFromFile
            } else if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let appDir = appSupport.appendingPathComponent("MinimalTranscribe")
                let configURL = appDir.appendingPathComponent("config.txt")
                
                if let keyFromConfig = try? String(contentsOf: configURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
                   !keyFromConfig.isEmpty {
                    apiKey = keyFromConfig
                }
            }
        }
        
        guard let validApiKey = apiKey else {
            completion(.failure(LLMError.noAPIKey(.groq)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(validApiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(LLMError.invalidResponse))
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                let errorMessage = "HTTP \(httpResponse.statusCode)"
                if let data = data, let errorBody = String(data: data, encoding: .utf8) {
                    print("Groq API Error: \(errorMessage) - \(errorBody)")
                }
                completion(.failure(LLMError.apiError(errorMessage)))
                return
            }
            
            guard let data = data else {
                completion(.failure(LLMError.noData))
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                if let dict = json as? [String: Any],
                   let choices = dict["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    completion(.success(content.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else {
                    completion(.failure(LLMError.invalidResponse))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func makeRequest(to url: String, headers: [String: String], payload: [String: Any], completion: @escaping (Result<Data, Error>) -> Void) {
        guard let requestURL = URL(string: url) else {
            completion(.failure(LLMError.invalidURL))
            return
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(LLMError.invalidResponse))
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                let errorMessage = "HTTP \(httpResponse.statusCode)"
                if let data = data, let errorBody = String(data: data, encoding: .utf8) {
                    print("LLM API Error: \(errorMessage) - \(errorBody)")
                }
                completion(.failure(LLMError.apiError(errorMessage)))
                return
            }
            
            guard let data = data else {
                completion(.failure(LLMError.noData))
                return
            }
            
            completion(.success(data))
        }.resume()
    }
}

enum LLMError: Error {
    case invalidURL
    case invalidResponse
    case apiError(String)
    case noData
    case noAPIKey(LLMProvider)
    case emptyTranscript
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid API response"
        case .apiError(let message):
            return "API Error: \(message)"
        case .noData:
            return "No data received"
        case .noAPIKey(let provider):
            return "No API key configured for \(provider.rawValue.capitalized)"
        case .emptyTranscript:
            return "No transcript to clean up"
        }
    }
}
