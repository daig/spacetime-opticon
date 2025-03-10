import Foundation
import AVFoundation
import SwiftUI

extension AudioRecorder {
    // MARK: - Recording
    
    /// Starts the audio recording process
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
    
    /// Stops the audio recording
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
} 