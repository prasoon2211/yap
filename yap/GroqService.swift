import Foundation
import AppKit

class GroqService: ObservableObject {
    private var apiKey: String?
    private let baseURL = "https://api.groq.com/openai/v1/audio/transcriptions"
    
    @Published var hasValidKey = false
    
    init() {
        loadAPIKey()
    }
    
    private func loadAPIKey() {
        // Try to get API key from environment variable first
        if let envKey = ProcessInfo.processInfo.environment["GROQ_API_KEY"] {
            self.apiKey = envKey
            self.hasValidKey = true
            print("Using GROQ_API_KEY from environment")
            return
        }
        
        // Try to load from app's config file
        if let storedKey = loadFromConfigFile() {
            self.apiKey = storedKey
            self.hasValidKey = true
            print("Using API key from config file")
            return
        }
        
        // Fallback to file in home directory
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let keyFile = homeDir.appendingPathComponent(".minimaltranscribe_key")
        
        do {
            let keyFromFile = try String(contentsOf: keyFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
            if !keyFromFile.isEmpty {
                self.apiKey = keyFromFile
                self.hasValidKey = true
                print("Using API key from ~/.minimaltranscribe_key")
                return
            }
        } catch {
            print("Could not read API key from file: \(error)")
        }
        
        // No API key found
        self.hasValidKey = false
        print("No API key found")
    }
    
    func saveAPIKey(_ key: String) -> Bool {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return false }
        
        if saveToConfigFile(trimmedKey) {
            self.apiKey = trimmedKey
            DispatchQueue.main.async {
                self.hasValidKey = true
            }
            print("API key saved to config file")
            return true
        }
        
        return false
    }
    
    private func getConfigFileURL() -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let appDir = appSupport.appendingPathComponent("MinimalTranscribe")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)
        
        return appDir.appendingPathComponent("config.txt")
    }
    
    private func saveToConfigFile(_ key: String) -> Bool {
        guard let configURL = getConfigFileURL() else { return false }
        
        do {
            try key.write(to: configURL, atomically: true, encoding: .utf8)
            return true
        } catch {
            print("Failed to save API key to config file: \(error)")
            return false
        }
    }
    
    private func loadFromConfigFile() -> String? {
        guard let configURL = getConfigFileURL() else { return nil }
        
        do {
            let key = try String(contentsOf: configURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
            return key.isEmpty ? nil : key
        } catch {
            // File doesn't exist or can't be read - this is normal for first run
            return nil
        }
    }
    
    
    func transcribeAudio(_ audioData: Data, completion: @escaping (Result<String, Error>) -> Void) {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            completion(.failure(GroqError.noAPIKey))
            return
        }
        
        guard let url = URL(string: baseURL) else {
            completion(.failure(GroqError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let httpBody = createMultipartBody(audioData: audioData, boundary: boundary)
        
        let task = URLSession.shared.uploadTask(with: request, from: httpBody) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(GroqError.invalidResponse))
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                let errorMessage = "HTTP \(httpResponse.statusCode)"
                if let data = data, let errorBody = String(data: data, encoding: .utf8) {
                    print("API Error: \(errorMessage) - \(errorBody)")
                }
                completion(.failure(GroqError.apiError(errorMessage)))
                return
            }
            
            guard let data = data else {
                completion(.failure(GroqError.noData))
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                if let dict = json as? [String: Any],
                   let text = dict["text"] as? String {
                    completion(.success(text))
                } else {
                    completion(.failure(GroqError.invalidResponse))
                }
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    private func createMultipartBody(audioData: Data, boundary: String) -> Data {
        var body = Data()
        
        // Add file parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add model parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("distil-whisper-large-v3-en".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add response_format parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("json".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }
}

enum GroqError: Error {
    case invalidURL
    case invalidResponse
    case apiError(String)
    case noData
    case noAPIKey
    
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
        case .noAPIKey:
            return "No API key configured"
        }
    }
}