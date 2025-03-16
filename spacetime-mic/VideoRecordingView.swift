import SwiftUI
import AVFoundation

struct VideoRecordingView: View {
    @State private var isRecording = false
    @State private var isPLYVideoRecording = false // New state for PLY video recording
    @State private var depthImage: UIImage?
    @State private var pointCloud: [SIMD3<Float>]? // New state for point cloud
    @State private var hasCameraPermission = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Depth Camera")
                .font(.title)
                .padding(.top)

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }

            if hasCameraPermission {
                // Camera View
                ZStack {
                    ARSceneDepthView(isRecording: $isRecording, depthImage: $depthImage, pointCloud: $pointCloud)
                        .frame(maxWidth: .infinity, maxHeight: 300)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray, lineWidth: 1)
                        )

                    if let depthImage = depthImage {
                        Image(uiImage: depthImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: 300)
                            .cornerRadius(12)
                            .opacity(0.7)
                            .blendMode(.overlay)
                            .clipped()
                    }
                }
                .padding(.horizontal)

                // Point count information
                if let pointCloud = pointCloud {
                    Text("Points: \(pointCloud.count)")
                        .foregroundColor(.gray)
                        .padding(.top, 4)
                }
                
                // Recording Controls
                VStack(spacing: 16) {
                    // Video Recording Button
                    Button(action: { isRecording.toggle() }) {
                        VStack {
                            Image(systemName: isRecording ? "stop.circle" : "video.circle")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 50, height: 50)
                                .foregroundColor(isRecording ? .red : .accentColor)
                            
                            Text(isRecording ? "Stop" : "Record")
                                .font(.caption)
                                .foregroundColor(isRecording ? .red : .primary)
                        }
                    }
                    
                    // PLY Video Recording Button
                    Button(action: { togglePLYVideoRecording() }) {
                        VStack {
                            Image(systemName: isPLYVideoRecording ? "stop.fill" : "record.circle")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 50, height: 50)
                                .foregroundColor(isPLYVideoRecording ? .red : .blue)
                            
                            Text(isPLYVideoRecording ? "Stop PLY" : "Record PLY")
                                .font(.caption)
                                .foregroundColor(isPLYVideoRecording ? .red : .blue)
                        }
                    }
                }
                .padding(.vertical, 12)

                // Save Buttons - Horizontal Layout
                HStack(spacing: 20) {
                    Button(action: {
                        if let pointCloud = pointCloud {
                            savePointCloudToFile(points: pointCloud)
                        } else {
                            print("No point cloud available")
                        }
                    }) {
                        VStack {
                            Image(systemName: "doc.text")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                            Text("Save PLY")
                                .font(.caption)
                        }
                        .frame(width: 80)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                    }
                    
                    Button(action: {
                        if let pointCloud = pointCloud {
                            DracoService.shared.savePointCloudToDracoFile(points: pointCloud)
                        } else {
                            print("No point cloud available")
                        }
                    }) {
                        VStack {
                            Image(systemName: "doc.zipper")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                            Text("Save Draco")
                                .font(.caption)
                        }
                        .frame(width: 80)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                
                // Add extra space at the bottom to avoid tab bar overlap
                Spacer()
                    .frame(height: 60)
                
            } else {
                // Permission Request
                Button("Request Camera Permission") {
                    requestCameraPermission()
                }
                .padding()
                
                Spacer()
            }
        }
        .padding()
        .onAppear {
            checkCameraPermission()
            // Set up notification observers
            NotificationCenter.default.addObserver(forName: .captureVideoFrame, object: nil, queue: .main) { _ in
                captureCurrentFrame()
            }
            
            // Set up observer for point cloud frame
            NotificationCenter.default.addObserver(forName: .pointCloudFrameAvailable, object: nil, queue: .main) { notification in
                if let points = notification.userInfo?["pointCloud"] as? [SIMD3<Float>] {
                    if isPLYVideoRecording {
                        capturePLYVideoFrame(points: points)
                    }
                }
            }
        }
    }

    // Function to toggle PLY video recording
    private func togglePLYVideoRecording() {
        isPLYVideoRecording.toggle()
        
        if isPLYVideoRecording {
            startPLYVideoRecording()
        } else {
            stopPLYVideoRecording()
        }
    }
    
    // Function to capture the current frame for PLY video
    private func captureCurrentFrame() {
        // We don't need to capture directly from here anymore
        // because the .pointCloudFrameAvailable notification will handle it
        // This function is now a no-op to avoid duplicate frame capture
        
        // The original code that causes duplicates:
        // if isPLYVideoRecording, let currentPoints = pointCloud {
        //     capturePLYVideoFrame(points: currentPoints)
        // }
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