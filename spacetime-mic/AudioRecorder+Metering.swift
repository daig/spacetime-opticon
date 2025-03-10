import Foundation
import AVFoundation
import SwiftUI

extension AudioRecorder {
    // MARK: - Audio Metering
    
    /// Updates the channel level meters based on buffer data
    internal func updateLevels(buffer: AVAudioPCMBuffer) {
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