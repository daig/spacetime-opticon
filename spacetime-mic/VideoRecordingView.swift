import SwiftUI

// MARK: - Video Recording View
struct VideoRecordingView: View {
    @State private var isRecording = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Video Recorder")
                .font(.title)
                .padding()
            
            Spacer()
            
            Text("Video recording functionality coming soon")
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
            
            // Stub recording button
            Button(action: {
                isRecording.toggle()
            }) {
                Image(systemName: isRecording ? "stop.circle" : "video.circle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .foregroundColor(isRecording ? .red : .accentColor)
            }
            .padding()
            
            // Recording status
            Text(isRecording ? "Recording..." : "Ready")
                .foregroundColor(isRecording ? .red : .primary)
                .padding()
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Preview Provider
#Preview {
    VideoRecordingView()
} 