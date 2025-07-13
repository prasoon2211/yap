import Foundation
import Carbon
import AppKit

class HotkeyManager: ObservableObject {
    @Published var isRecording = false
    @Published var isUploading = false
    
    private var eventHotkey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let audioRecorder = AudioRecorder()
    let groqService = GroqService()
    
    init() {
        setupHotkey()
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
        audioRecorder.startRecording()
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
                    ClipboardManager.copyToClipboard(transcript)
                    // Play success sound
                    NSSound(named: NSSound.Name("Ping"))?.play()
                    
                case .failure(let error):
                    print("Transcription failed: \(error)")
                    // Play error sound
                    NSSound(named: NSSound.Name("Basso"))?.play()
                }
            }
        }
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
