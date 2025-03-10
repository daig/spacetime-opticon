import Foundation
import AVFoundation
import SwiftUI

extension AudioRecorder {
    // MARK: - Setup and Permissions
    
    /// Sets up the audio engine for recording
    internal func setupAudioEngine() {
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
    
    /// Checks microphone permission status
    internal func checkPermission() {
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
} 