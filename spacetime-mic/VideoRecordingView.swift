import SwiftUI
import AVFoundation
import UIKit
import ARKit

// MARK: - Video Recording View
struct VideoRecordingView: View {
    @State private var isRecording = false
    @State private var depthImage: UIImage?
    @State private var hasCameraPermission = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Depth Camera")
                .font(.title)
                .padding()
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
            
            if hasCameraPermission {
                // Display the AR scene depth view with proper overlay
                ZStack {
                    // AR view (camera feed)
                    ARSceneDepthView(isRecording: $isRecording, depthImage: $depthImage)
                        .frame(maxWidth: .infinity, maxHeight: 400)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                    
                    // Depth image overlay - fully overlapping with camera view
                    if let depthImage = depthImage {
                        Image(uiImage: depthImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: 400)
                            .cornerRadius(12)
                            .opacity(0.7)
                            .blendMode(.overlay)
                            .clipped()
                    }
                }
                .padding(.horizontal)
                
                // Recording button
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
            } else {
                Button("Request Camera Permission") {
                    requestCameraPermission()
                }
                .padding()
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            checkCameraPermission()
        }
    }
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            hasCameraPermission = true
        case .notDetermined:
            requestCameraPermission()
        case .denied, .restricted:
            errorMessage = "Camera access is required for AR scene depth capture"
            hasCameraPermission = false
        @unknown default:
            errorMessage = "Unknown camera permission status"
            hasCameraPermission = false
        }
    }
    
    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                self.hasCameraPermission = granted
                if !granted {
                    self.errorMessage = "Camera access is required for AR scene depth capture"
                }
            }
        }
    }
}
