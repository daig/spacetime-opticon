import SwiftUI
import AVFoundation
import Combine

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