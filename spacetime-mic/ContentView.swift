import SwiftUI
import AVFoundation
import Combine
import ARKit
import SceneKit
import RealityKit

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
                
            PLYViewer()
                .tabItem {
                    Label("View PLY", systemImage: "cube.transparent.fill")
                }
                .tag(2)
                
            DracoPointCloudTestView()
                .tabItem {
                    Label("Draco", systemImage: "cube.transparent")
                }
                .tag(3)
        }
    }
}

// MARK: - Preview Provider
#Preview {
    ContentView()
} 