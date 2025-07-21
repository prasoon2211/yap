import Foundation
import Carbon
import AppKit

class HotkeyManager: ObservableObject {
    @Published var isRecording = false
    @Published var isUploading = false
    @Published var isCleaningUp = false
    
    private var eventHotkey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let audioRecorder = AudioRecorder()
    let groqService = GroqService()
    private let configManager: ConfigurationManager
    private var llmService: LLMService?
    
    init(configManager: ConfigurationManager) {
        self.configManager = configManager
        setupHotkey()
    }
    
    func setLLMService(_ llmService: LLMService) {
        self.llmService = llmService
    }
    
    deinit {
        cleanup()
    }
    
    private func setupHotkey() {
        // Register Shift+Command+Space hotkey
        let keyCode = UInt32(kVK_Space)
        let modifiers = UInt32(shiftKey | cmdKey)
        
        let hotKeyID = EventHotKeyID(signature: OSType("YTAP".fourCharCodeValue), id: 1)
        
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &eventHotkey
        )
        
        if status == noErr {
            print("Hotkey registered successfully")
            installEventHandler()
        } else {
            print("Failed to register hotkey: \(status)")
        }
    }
    
    private func installEventHandler() {
        let eventSpecs = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        ]
        
        let callback: EventHandlerUPP = { (handler, event, userData) -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let hotkeyManager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            
            DispatchQueue.main.async {
                hotkeyManager.toggleRecording()
            }
            
            return OSStatus(noErr)
        }
        
        let userData = Unmanaged.passUnretained(self).toOpaque()
        
        InstallEventHandler(
            GetEventDispatcherTarget(),
            callback,
            1,
            eventSpecs,
            userData,
            &eventHandler
        )
    }
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        print("Starting recording...")
        isRecording = true
        // Play start sound
        NSSound(named: NSSound.Name("Pop"))?.play()
        
        // Small delay to let the sound play before starting audio engine
        // This prevents conflicts with Bluetooth devices switching to call mode
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.audioRecorder.startRecording()
        }
    }
    
    private func stopRecording() {
        print("Stopping recording...")
        isRecording = false
        
        if let audioData = audioRecorder.stopRecording() {
            print("Got audio data: \(audioData.count) bytes")
            transcribeAudio(audioData)
        } else {
            // Play error sound if no audio data
            NSSound(named: NSSound.Name("Basso"))?.play()
        }
    }
    
    private func transcribeAudio(_ audioData: Data) {
        isUploading = true
        print("Uploading audio to Groq API...")
        
        groqService.transcribeAudio(audioData) { [weak self] result in
            DispatchQueue.main.async {
                self?.isUploading = false
                
                switch result {
                case .success(let transcript):
                    print("Transcription successful: \"\(transcript)\"")
                    self?.processTranscript(transcript)
                    
                case .failure(let error):
                    print("Transcription failed: \(error)")
                    // Play error sound
                    NSSound(named: NSSound.Name("Basso"))?.play()
                }
            }
        }
    }
    
    private func processTranscript(_ transcript: String) {
        // Check if cleanup is enabled and we have an LLM service
        guard configManager.cleanupEnabled,
              let llmService = self.llmService else {
            // No cleanup - copy original transcript and finish
            finishWithTranscript(transcript)
            return
        }
        
        // Check if the selected provider is configured
        let provider = llmService.selectedModel.provider
        if provider != .groq && !configManager.hasAPIKey(for: provider) {
            // Provider not configured - fall back to original transcript
            print("LLM provider \(provider.rawValue) not configured, using original transcript")
            finishWithTranscript(transcript)
            return
        }
        
        // Proceed with cleanup
        isCleaningUp = true
        print("Cleaning up transcript with \(llmService.selectedModel.rawValue)...")
        
        llmService.cleanupText(transcript) { [weak self] result in
            DispatchQueue.main.async {
                self?.isCleaningUp = false
                
                switch result {
                case .success(let cleanedTranscript):
                    print("Cleanup successful")
                    self?.finishWithTranscript(cleanedTranscript)
                    
                case .failure(let error):
                    print("Cleanup failed: \(error)")
                    // Fall back to original transcript
                    self?.finishWithTranscript(transcript)
                }
            }
        }
    }
    
    private func finishWithTranscript(_ transcript: String) {
        ClipboardManager.copyToClipboard(transcript)
        // Play success sound
        NSSound(named: NSSound.Name("Ping"))?.play()
        print("Final transcript copied to clipboard: \"\(transcript)\"")
    }
    
    private func cleanup() {
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
        }
        if let eventHotkey = eventHotkey {
            UnregisterEventHotKey(eventHotkey)
        }
    }
}

// Helper extension to convert string to FourCharCode
extension String {
    var fourCharCodeValue: FourCharCode {
        var result: FourCharCode = 0
        if let data = self.data(using: String.Encoding.macOSRoman) {
            data.withUnsafeBytes { bytes in
                for i in 0..<min(4, data.count) {
                    result = result << 8 + FourCharCode(bytes[i])
                }
            }
        }
        return result
    }
}
