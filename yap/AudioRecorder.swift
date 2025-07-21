import Foundation
import AVFoundation
import AppKit

class AudioRecorder: NSObject, ObservableObject {
    private var audioEngine: AVAudioEngine
    private var recordingData: Data = Data()
    private var isRecording = false
    
    override init() {
        self.audioEngine = AVAudioEngine()
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        // Request microphone permission
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            print("Microphone access authorized")
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if granted {
                    print("Microphone access granted")
                } else {
                    print("Microphone access denied")
                }
            }
        case .denied, .restricted:
            print("Microphone access denied")
            showMicrophonePermissionAlert()
        @unknown default:
            break
        }
    }
    
    private func showMicrophonePermissionAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Microphone Access Required"
            alert.informativeText = "MinimalTranscribe needs microphone access to transcribe your speech. Please enable it in System Preferences > Security & Privacy > Privacy > Microphone."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Quit")
            alert.addButton(withTitle: "Open System Preferences")
            
            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
            }
            NSApplication.shared.terminate(nil)
        }
    }
    
    func startRecording() {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
            print("Microphone access not authorized")
            return
        }
        
        guard !isRecording else {
            print("Already recording")
            return
        }
        
        print("Starting audio recording...")
        recordingData = Data()
        isRecording = true
        
        // Stop and reset engine completely to handle device changes
        audioEngine.stop()
        audioEngine.reset()
        
        // Create a fresh engine instance to handle device switches properly
        audioEngine = AVAudioEngine()
        
        let inputNode = audioEngine.inputNode
        
        // Give the system a moment to initialize the new input device
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self, self.isRecording else { return }
            
            let inputFormat = inputNode.outputFormat(forBus: 0)
            print("Input format: \(inputFormat.sampleRate) Hz, \(inputFormat.channelCount) channels")
            
            // Check if we have valid input
            guard inputFormat.channelCount > 0 && inputFormat.sampleRate > 0 else {
                print("Invalid input format - channels: \(inputFormat.channelCount), sampleRate: \(inputFormat.sampleRate)")
                self.isRecording = false
                return
            }
            
            // Remove any existing tap first
            inputNode.removeTap(onBus: 0)
            
            // Install tap with proper format
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
                self?.processAudioBuffer(buffer)
            }
            
            print("Audio tap installed successfully")
            
            do {
                // Prepare and start the audio engine
                self.audioEngine.prepare()
                try self.audioEngine.start()
                print("Audio engine started successfully")
                print("Audio engine running: \(self.audioEngine.isRunning)")
            } catch {
                print("Failed to start audio engine: \(error)")
                self.isRecording = false
            }
        }
    }
    
    func stopRecording() -> Data? {
        guard isRecording else {
            print("Not currently recording")
            return nil
        }
        
        print("Stopping audio recording...")
        isRecording = false
        
        // Stop engine and remove tap
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        print("Raw recording data: \(recordingData.count) bytes")
        
        if !recordingData.isEmpty {
            let wavData = createWAVFile(from: recordingData)
            print("Recording stopped, captured \(wavData.count) bytes WAV data")
            return wavData
        } else {
            print("No audio data captured")
            return nil
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { 
            return 
        }
        
        let frameCount = Int(buffer.frameLength)
        let inputSampleRate = buffer.format.sampleRate
        let outputSampleRate = 16000.0
        
        // Simple downsampling: take every nth sample to get approximately 16kHz
        let downsampleRatio = max(1, Int(inputSampleRate / outputSampleRate))
        
        var int16Data = Data()
        
        for i in stride(from: 0, to: frameCount, by: downsampleRatio) {
            let sample = channelData[i]
            // Clamp the sample to valid range [-1.0, 1.0] before converting
            let clampedSample = max(-1.0, min(1.0, sample))
            let scaledSample = clampedSample * 32767.0
            let int16Sample = Int16(scaledSample)
            int16Data.append(contentsOf: withUnsafeBytes(of: int16Sample.littleEndian) { Data($0) })
        }
        
        recordingData.append(int16Data)
        
        // Debug log first few buffers
        if recordingData.count <= 10000 {
            print("Buffer processed: \(frameCount) frames, total data: \(recordingData.count) bytes")
        }
    }
    
    private func createWAVFile(from pcmData: Data) -> Data {
        let sampleRate: UInt32 = 16000
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = sampleRate * UInt32(channels * bitsPerSample / 8)
        let blockAlign = channels * bitsPerSample / 8
        let dataSize = UInt32(pcmData.count)
        let fileSize = 36 + dataSize
        
        var wavHeader = Data()
        
        // RIFF header
        wavHeader.append("RIFF".data(using: .ascii)!)
        wavHeader.append(withUnsafeBytes(of: fileSize.littleEndian) { Data($0) })
        wavHeader.append("WAVE".data(using: .ascii)!)
        
        // fmt chunk
        wavHeader.append("fmt ".data(using: .ascii)!)
        wavHeader.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        wavHeader.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })
        wavHeader.append(withUnsafeBytes(of: channels.littleEndian) { Data($0) })
        wavHeader.append(withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
        wavHeader.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        wavHeader.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        wavHeader.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })
        
        // data chunk
        wavHeader.append("data".data(using: .ascii)!)
        wavHeader.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })
        
        var wavFile = Data()
        wavFile.append(wavHeader)
        wavFile.append(pcmData)
        
        return wavFile
    }
}