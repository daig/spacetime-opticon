import SwiftUI
import AVFoundation
import Combine

// Main AudioRecorder class that handles ambisonic microphone input
public class AudioRecorder: ObservableObject {
    // Audio engine and input node
    internal var audioEngine: AVAudioEngine?
    internal var inputNode: AVAudioInputNode?
    
    // Properties for metering
    @Published public var channelLevels: [Float] = [0, 0, 0, 0]
    internal var levelTimer: Timer?
    
    // State management
    @Published public var isRecording = false
    @Published public var hasPermission = false
    @Published public var errorMessage: String?
    
    // Log messages
    @Published public var logMessages: String = "Audio Interface Debug Log:\n"
    
    // Audio file properties
    internal var audioFile: AVAudioFile?
    internal var recordingURL: URL?
    
    public init() {
        setupAudioEngine()
        checkPermission()
    }
    
} 