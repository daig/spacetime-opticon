import SwiftUI
import AVFoundation
import Combine


// MARK: - Content View
struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            AudioRecordingView()
                .tabItem {
                    Label("Audio", systemImage: "waveform")
                }
                .tag(0)
            
            VideoRecordingView()
                .tabItem {
                    Label("Video", systemImage: "video")
                }
                .tag(1)
        }
    }
}

// MARK: - Preview Provider
#Preview {
    ContentView()
} 