import SwiftUI
import AVFoundation
import ARKit
import RealityKit

// MARK: - AR Camera View
struct ARSceneDepthView: UIViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var depthImage: UIImage?
    
    class Coordinator: NSObject, ARSessionDelegate {
        var parent: ARSceneDepthView
        
        init(_ parent: ARSceneDepthView) {
            self.parent = parent
        }
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            // Check if depth data is available
            guard let depthData = frame.sceneDepth?.depthMap else { return }
            
            // Convert depth data to an image and display it
            let ciImage = CIImage(cvPixelBuffer: depthData)
            
            // Apply heat map colorization for better depth visualization
            if let colorizedDepthImage = applyHeatMapToDepthImage(ciImage) {
                DispatchQueue.main.async {
                    // Correct orientation to match camera feed
                    self.parent.depthImage = self.rotateImage(colorizedDepthImage, orientation: .right)
                }
            } else {
                // Fallback to regular depth image
                let context = CIContext()
                if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                    DispatchQueue.main.async {
                        // Correct orientation to match camera feed
                        self.parent.depthImage = self.rotateImage(UIImage(cgImage: cgImage), orientation: .right)
                    }
                }
            }
        }
        
        // Rotates an image to match the camera feed orientation
        private func rotateImage(_ image: UIImage, orientation: UIImage.Orientation) -> UIImage {
            if let cgImage = image.cgImage {
                return UIImage(cgImage: cgImage, scale: image.scale, orientation: orientation)
            }
            return image
        }
        
        // Applies a heat map coloring to a depth image
        private func applyHeatMapToDepthImage(_ depthImage: CIImage) -> UIImage? {
            // Create a color kernel to map depth values to colors
            let colorKernel = CIColorKernel(source:
                """
                kernel vec4 depthToColor(__sample depth) {
                    float normalizedDepth = depth.r; // Depth is usually stored in the red channel
                    
                    // Create a heat map color scheme
                    vec4 color;
                    if (normalizedDepth < 0.2) {
                        // Blue to cyan
                        color = mix(vec4(0.0, 0.0, 1.0, 1.0), vec4(0.0, 1.0, 1.0, 1.0), normalizedDepth * 5.0);
                    } else if (normalizedDepth < 0.4) {
                        // Cyan to green
                        color = mix(vec4(0.0, 1.0, 1.0, 1.0), vec4(0.0, 1.0, 0.0, 1.0), (normalizedDepth - 0.2) * 5.0);
                    } else if (normalizedDepth < 0.6) {
                        // Green to yellow
                        color = mix(vec4(0.0, 1.0, 0.0, 1.0), vec4(1.0, 1.0, 0.0, 1.0), (normalizedDepth - 0.4) * 5.0);
                    } else if (normalizedDepth < 0.8) {
                        // Yellow to red
                        color = mix(vec4(1.0, 1.0, 0.0, 1.0), vec4(1.0, 0.0, 0.0, 1.0), (normalizedDepth - 0.6) * 5.0);
                    } else {
                        // Red to white
                        color = mix(vec4(1.0, 0.0, 0.0, 1.0), vec4(1.0, 1.0, 1.0, 1.0), (normalizedDepth - 0.8) * 5.0);
                    }
                    
                    return color;
                }
                """
            )
            
            guard let kernel = colorKernel else { return nil }
            
            // Apply the color kernel to the depth image
            guard let colorizedImage = kernel.apply(extent: depthImage.extent, 
                                                 arguments: [depthImage]) else { return nil }
            
            // Convert CIImage to UIImage
            let context = CIContext()
            guard let cgImage = context.createCGImage(colorizedImage, from: colorizedImage.extent) else { return nil }
            
            return UIImage(cgImage: cgImage)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Set up AR configuration
        let config = ARWorldTrackingConfiguration()
        
        // Enable scene depth if supported
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        } else {
            print("Scene depth is not supported on this device")
        }
        
        // Set the session delegate
        arView.session.delegate = context.coordinator
        
        // Run the session
        arView.session.run(config)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Handle updates if needed
    }
}

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
                            .aspectRatio(contentMode: .fill) // Changed from .fit to .fill
                            .frame(maxWidth: .infinity, maxHeight: 400)
                            .cornerRadius(12)
                            .opacity(0.7)
                            .clipped() // Ensure it doesn't extend beyond bounds
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

// MARK: - Preview Provider
#Preview {
    VideoRecordingView()
} 