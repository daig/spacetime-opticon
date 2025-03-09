//
//  ContentView.swift
//  spacetime-mic
//
//  Created by David Girardo on 3/9/25.
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - Audio Recorder
class AudioRecorder: ObservableObject {
    // Audio session and engine
    private var audioSession: AVAudioSession?
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
        setupAudioSession()
        checkPermission()
    }
    
    private func log(_ message: String) {
        DispatchQueue.main.async {
            self.logMessages += message + "\n"
        }
    }
    
    private func setupAudioSession() {
        do {
            audioSession = AVAudioSession.sharedInstance()
            
            // Use playAndRecord to allow both input and output
            try audioSession?.setCategory(.playAndRecord, 
                                        mode: .default,
                                        options: [.allowBluetoothA2DP, .defaultToSpeaker, .allowAirPlay])
            
            // Set preferred input to be digital (USB)
            try audioSession?.setPreferredInput(audioSession?.availableInputs?.first { 
                $0.portType == .usbAudio || $0.portType == .builtInMic 
            })
            
            try audioSession?.setActive(true)
            
            // Log audio session details for debugging
            if let currentRoute = audioSession?.currentRoute {
                log("Current audio route:")
                for output in currentRoute.outputs {
                    log("Output: \(output.portType) - \(output.portName)")
                }
                for input in currentRoute.inputs {
                    log("Input: \(input.portType) - \(input.portName)")
                    log("Channel count: \(input.channels?.count ?? 0)")
                    if let channels = input.channels {
                        for (index, channel) in channels.enumerated() {
                            log("Channel \(index): \(channel.channelName) - \(channel.channelLabel)")
                        }
                    }
                }
            }
            
        } catch {
            errorMessage = "Failed to set up audio session: \(error.localizedDescription)"
            log("Audio session setup error: \(error)")
        }
    }
    
    private func checkPermission() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            hasPermission = true
        case .denied:
            hasPermission = false
            errorMessage = "Microphone access has been denied"
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
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
            
            // Print available audio devices and current input for debugging
            let audioSession = AVAudioSession.sharedInstance()
            log("Current route: \(audioSession.currentRoute.description)")
            log("Number of channels on input: \(audioSession.inputNumberOfChannels)")
            
            // Try to detect USB audio interface
            if audioSession.inputNumberOfChannels < 4 {
                errorMessage = "No 4-channel audio interface detected. Connect your ambisonic microphone via USB-C."
                return
            }
            
            // Get document directory for saving recordings
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = "recording_\(Date().timeIntervalSince1970).caf"
            recordingURL = documentsPath.appendingPathComponent(fileName)
            
            // Get the input format from the hardware directly
            guard let hardwareFormat = inputNode?.inputFormat(forBus: 0) else {
                errorMessage = "Could not get input format from hardware"
                return
            }
            
            log("Hardware format: \(hardwareFormat.description)")
            log("Hardware channel count: \(hardwareFormat.channelCount)")
            
            // Check if the hardware has 4 channels
            if hardwareFormat.channelCount != 4 {
                log("Warning: Hardware reports \(hardwareFormat.channelCount) channels, but we need 4")
                
                // Try to create a format with 4 channels
                guard let format = AVAudioFormat(
                    commonFormat: .pcmFormatFloat32,
                    sampleRate: hardwareFormat.sampleRate,
                    channels: 4,
                    interleaved: false
                ) else {
                    errorMessage = "Failed to create 4-channel audio format"
                    return
                }
                log("Created custom 4-channel format: \(format.description)")
            } else {
                log("Using hardware format directly: \(hardwareFormat.description)")
            }
            
            // We'll use the hardware format directly
            let format = hardwareFormat
            
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
                    AVSampleRateKey: format.sampleRate,
                    AVNumberOfChannelsKey: format.channelCount,
                    AVLinearPCMBitDepthKey: 32,
                    AVLinearPCMIsFloatKey: true,
                    AVLinearPCMIsNonInterleaved: !format.isInterleaved,
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

// MARK: - Level Meter View
struct LevelMeterView: View {
    var level: Float
    var channelName: String
    
    var body: some View {
        VStack {
            Text(channelName)
                .font(.caption)
                .padding(.bottom, 2)
            
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    // Background of the meter
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    
                    // Colored bar representing the level
                    Rectangle()
                        .fill(levelColor)
                        .frame(
                            width: geometry.size.width,
                            height: CGFloat(level) * geometry.size.height
                        )
                }
            }
            .cornerRadius(4)
            
            Text("\(Int(level * 100))%")
                .font(.caption)
                .padding(.top, 2)
        }
    }
    
    private var levelColor: Color {
        switch level {
        case 0..<0.5:
            return .green
        case 0.5..<0.8:
            return .yellow
        default:
            return .red
        }
    }
}

// MARK: - Content View
struct ContentView: View {
    @StateObject private var audioRecorder = AudioRecorder()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showLogs = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Ambisonic Audio Recorder")
                .font(.title)
                .padding()
            
            // Display status and errors
            if let errorMessage = audioRecorder.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
            
            // Level meters for all 4 channels
            HStack(spacing: 20) {
                LevelMeterView(level: audioRecorder.channelLevels[0], channelName: "W")
                LevelMeterView(level: audioRecorder.channelLevels[1], channelName: "X")
                LevelMeterView(level: audioRecorder.channelLevels[2], channelName: "Y")
                LevelMeterView(level: audioRecorder.channelLevels[3], channelName: "Z")
            }
            .frame(height: 200)
            .padding(.horizontal)
            
            // Recording controls
            HStack(spacing: 30) {
                Button(action: {
                    if audioRecorder.isRecording {
                        audioRecorder.stopRecording()
                    } else {
                        audioRecorder.startRecording()
                    }
                }) {
                    Image(systemName: audioRecorder.isRecording ? "stop.circle" : "record.circle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .foregroundColor(audioRecorder.isRecording ? .red : .accentColor)
                }
            }
            .padding()
            
            // Recording status
            Text(audioRecorder.isRecording ? "Recording..." : "Ready")
                .foregroundColor(audioRecorder.isRecording ? .red : .primary)
                .padding()
            
            // Toggle logs button
            Button(action: {
                showLogs.toggle()
            }) {
                Text(showLogs ? "Hide Logs" : "Show Logs")
                    .foregroundColor(.blue)
            }
            .padding(.bottom, 4)
            
            // Log display area
            if showLogs {
                ScrollView {
                    Text(audioRecorder.logMessages)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(height: 200)
                .background(Color.black.opacity(0.05))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding()
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // App became active
            } else if newPhase == .inactive {
                // App became inactive
                if audioRecorder.isRecording {
                    audioRecorder.stopRecording()
                }
            }
        }
    }
}

// MARK: - Preview Provider
#Preview {
    ContentView()
}
