import SwiftUI
import AVFoundation
import UIKit
import ARKit

struct VideoRecordingView: View {
    @State private var isRecording = false
    @State private var depthImage: UIImage?
    @State private var pointCloud: [SIMD3<Float>]? // New state for point cloud
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
                ZStack {
                    ARSceneDepthView(isRecording: $isRecording, depthImage: $depthImage, pointCloud: $pointCloud)
                        .frame(maxWidth: .infinity, maxHeight: 400)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray, lineWidth: 1)
                        )

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

                Button(action: { isRecording.toggle() }) {
                    Image(systemName: isRecording ? "stop.circle" : "video.circle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .foregroundColor(isRecording ? .red : .accentColor)
                }
                .padding()

                Text(isRecording ? "Recording..." : "Ready")
                    .foregroundColor(isRecording ? .red : .primary)
                    .padding()

                if let pointCloud = pointCloud {
                    Text("Points: \(pointCloud.count)")
                        .foregroundColor(.gray)
                }

                HStack(spacing: 15) {
                    Button(action: {
                        if let pointCloud = pointCloud {
                            savePointCloudToFile(points: pointCloud)
                        } else {
                            print("No point cloud available")
                        }
                    }) {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("Save as PLY")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                    }
                    
                    Button(action: {
                        if let pointCloud = pointCloud {
                            savePointCloudToDracoFile(points: pointCloud)
                        } else {
                            print("No point cloud available")
                        }
                    }) {
                        HStack {
                            Image(systemName: "doc.zipper")
                            Text("Save Compressed")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
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
