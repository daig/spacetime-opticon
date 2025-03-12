import SwiftUI
import AVFoundation
import ARKit
import RealityKit
import UIKit
import Metal
import MetalKit

// MARK: - AR Camera View
struct ARSceneDepthView: UIViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var depthImage: UIImage?
    
    class Coordinator: NSObject, ARSessionDelegate {
        var parent: ARSceneDepthView
        
        // Static CIContext and CIColorKernel for one-time setup
        static let ciContext = CIContext()
        static let colorKernel: CIColorKernel = {
            guard let url = Bundle.main.url(forResource: "default", withExtension: "metallib"),
                  let data = try? Data(contentsOf: url),
                  let kernel = try? CIColorKernel(functionName: "depthToColor", fromMetalLibraryData: data) else {
                fatalError("Failed to load Metal library or create CIColorKernel")
            }
            return kernel
        }()
        
        // Initialize with the parent view
        init(_ parent: ARSceneDepthView) {
            self.parent = parent
        }
        
        // Handle AR session frame updates
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            // Ensure depth data is available
            guard let depthData = frame.sceneDepth?.depthMap else { return }
            
            // Create a CIImage from the depth map's CVPixelBuffer
            let depthCIImage = CIImage(cvPixelBuffer: depthData)
            
            // Apply the static Core Image kernel to process the depth map
            if let outputImage = Coordinator.colorKernel.apply(extent: depthCIImage.extent, arguments: [depthCIImage]) {
                // Render the output CIImage to a CGImage using the static CIContext
                if let cgImage = Coordinator.ciContext.createCGImage(outputImage, from: outputImage.extent) {
                    let uiImage = UIImage(cgImage: cgImage)
                    // Update the depthImage binding on the main thread with corrected orientation
                    DispatchQueue.main.async {
                        self.parent.depthImage = self.rotateImage(uiImage, orientation: .right)
                    }
                }
            }
        }
        
        // Rotate the image to match the desired display orientation
        private func rotateImage(_ image: UIImage, orientation: UIImage.Orientation) -> UIImage {
            guard let cgImage = image.cgImage else { return image }
            return UIImage(cgImage: cgImage, scale: image.scale, orientation: orientation)
        }
    }
    
    // Create the coordinator
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // Set up the ARView
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Configure AR session
        let config = ARWorldTrackingConfiguration()
        
        // Enable scene depth if supported
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        } else {
            print("Scene depth is not supported on this device")
        }
        
        // Assign the session delegate
        arView.session.delegate = context.coordinator
        
        // Start the AR session
        arView.session.run(config)
        
        return arView
    }
    
    // Update the UIView (if needed)
    func updateUIView(_ uiView: ARView, context: Context) {
        // No updates needed for this implementation
    }
}
