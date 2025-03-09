import SwiftUI
import AVFoundation
import Combine

class AudioRecorder: ObservableObject {
    // Audio engine and input node
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    
    // Properties for metering
    @Published var channelLevels: [Float] = [0, 0, 0, 0]
    private var levelTimer: Timer?
    
    // State management
    @Published var isRecording = false
    @Published var hasPermission = false
    @Published var errorMessage: String?
    
    // Log messages
    @Published var logMessages: String = "Audio Interface Debug Log:\n"
    
    // Audio file properties
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?
    
    init() {
        setupAudioEngine()
        checkPermission()
    }
    
    private func log(_ message: String) {
        DispatchQueue.main.async {
            self.logMessages += message + "\n"
        }
    }
    
    private func setupAudioEngine() {
        do {
            audioEngine = AVAudioEngine()
            inputNode = audioEngine?.inputNode
            
            // Log audio engine details for debugging
            if let inputNode = inputNode {
                let format = inputNode.inputFormat(forBus: 0)
                log("Input format: \(format.description)")
                log("Channel count: \(format.channelCount)")
            }
            
        } catch {
            errorMessage = "Failed to set up audio engine: \(error.localizedDescription)"
            log("Audio engine setup error: \(error)")
        }
    }
    
    private func checkPermission() {
        // On macOS, we need to check microphone permission
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            hasPermission = true
        case .denied:
            hasPermission = false
            errorMessage = "Microphone access has been denied"
        case .restricted:
            hasPermission = false
            errorMessage = "Microphone access is restricted"
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.hasPermission = granted
                    if !granted {
                        self?.errorMessage = "Microphone access is required"
                    }
                }
            }
        @unknown default:
            hasPermission = false
            errorMessage = "Unknown permission status"
        }
    }
    
    func startRecording() {
        guard hasPermission else {
            errorMessage = "No permission to record audio"
            return
        }
        
        do {
            // Initialize engine if needed
            if audioEngine == nil {
                audioEngine = AVAudioEngine()
                inputNode = audioEngine?.inputNode
            }
            
            // Get the input format from the hardware directly
            guard let hardwareFormat = inputNode?.inputFormat(forBus: 0) else {
                errorMessage = "Could not get input format from hardware"
                return
            }
            
            log("Hardware format: \(hardwareFormat.description)")
            log("Hardware channel count: \(hardwareFormat.channelCount)")
            
            // Try to detect USB audio interface
            if hardwareFormat.channelCount < 4 {
                errorMessage = "No 4-channel audio interface detected. Connect your ambisonic microphone via USB-C."
                return
            }
            
            // Get document directory for saving recordings
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = "recording_\(Date().timeIntervalSince1970).caf"
            recordingURL = documentsPath.appendingPathComponent(fileName)
            
            // Check if recordingURL is valid
            guard let recordingURL = recordingURL else {
                errorMessage = "Failed to create recording URL"
                return
            }
            
            log("Recording to: \(recordingURL.path)")
            
            // Try to prepare the directory
            do {
                let directoryURL = recordingURL.deletingLastPathComponent()
                if !FileManager.default.fileExists(atPath: directoryURL.path) {
                    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
                    log("Created directory at \(directoryURL.path)")
                }
            } catch {
                errorMessage = "Failed to create recording directory: \(error.localizedDescription)"
                log("Directory error: \(error)")
                return
            }
            
            // Create the audio file
            do {
                // Prepare settings dictionary manually to ensure compatibility
                var settings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVSampleRateKey: hardwareFormat.sampleRate,
                    AVNumberOfChannelsKey: hardwareFormat.channelCount,
                    AVLinearPCMBitDepthKey: 32,
                    AVLinearPCMIsFloatKey: true,
                    AVLinearPCMIsNonInterleaved: !hardwareFormat.isInterleaved,
                ]
                
                log("Creating audio file with settings: \(settings)")
                
                audioFile = try AVAudioFile(forWriting: recordingURL, settings: settings)
                log("Successfully created audio file")
            } catch {
                errorMessage = "Failed to create audio file: \(error.localizedDescription)"
                log("Audio file creation error: \(error)")
                return
            }
            
            // Install a tap on the input node to capture audio
            do {
                inputNode?.installTap(onBus: 0, bufferSize: 4096, format: hardwareFormat) { [weak self] buffer, time in
                    // Write buffer to file
                    do {
                        try self?.audioFile?.write(from: buffer)
                    } catch {
                        self?.log("Error writing to file: \(error)")
                    }
                    
                    // Calculate levels for each channel
                    self?.updateLevels(buffer: buffer)
                }
                log("Successfully installed tap on input node")
            } catch {
                errorMessage = "Failed to install tap: \(error.localizedDescription)"
                log("Install tap error: \(error)")
                return
            }
            
            // Start the engine
            do {
                try audioEngine?.start()
                isRecording = true
                log("Recording started with \(hardwareFormat.channelCount) channels")
            } catch {
                errorMessage = "Failed to start audio engine: \(error.localizedDescription)"
                log("Engine start error: \(error)")
                return
            }
            
            // Start a timer to update UI
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                // This will trigger UI updates through the @Published channelLevels
            }
            
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            log("Recording error: \(error)")
        }
    }
    
    func stopRecording() {
        // Remove the tap from the input node
        inputNode?.removeTap(onBus: 0)
        
        // Stop the engine
        audioEngine?.stop()
        
        // Stop the timer
        levelTimer?.invalidate()
        levelTimer = nil
        
        // Reset levels
        channelLevels = [0, 0, 0, 0]
        isRecording = false
    }
    
    private func updateLevels(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        // Process each channel up to the number of available channels
        let numChannels = min(4, Int(buffer.format.channelCount))
        
        for channel in 0..<numChannels {
            var sum: Float = 0
            let data = channelData[channel]
            let bufferStride = buffer.stride
            
            // Sum the squares of the samples
            for i in stride(from: 0, to: Int(buffer.frameLength), by: bufferStride) {
                let sample = data[i]
                sum += sample * sample
            }
            
            // Calculate RMS (Root Mean Square)
            let rms = sqrt(sum / Float(buffer.frameLength))
            
            // Convert to decibels
            var db = 20 * log10(rms)
            
            // Normalize between 0 and 1
            db = max(db, -80) // Noise floor
            let normalizedValue = (db + 80) / 80 // Map -80...0 to 0...1
            
            // Update the value on the main thread
            DispatchQueue.main.async {
                self.channelLevels[channel] = normalizedValue
            }
        }
        
        // Zero out any unused channels
        for channel in numChannels..<4 {
            DispatchQueue.main.async {
                self.channelLevels[channel] = 0
            }
        }
    }
} 