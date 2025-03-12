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
        
        static let metalDevice: MTLDevice = {
            guard let device = MTLCreateSystemDefaultDevice() else { fatalError("Metal is not supported on this device") }
            return device }()
        
        static let commandQueue: MTLCommandQueue = {
            guard let queue = metalDevice.makeCommandQueue() else { fatalError("Couldn't create metal command queue") }
            return queue }()
        
        static let library: MTLLibrary = {
            guard let library = metalDevice.makeDefaultLibrary() else { fatalError("Failed to create metal library") }
            return library }()
        
        let pipelineState: MTLComputePipelineState
        
        init(_ parent: ARSceneDepthView) {
            self.parent = parent
            
            do {
                guard let function = Self.library.makeFunction(name: "SpacetimeMic::depthToColorKernelImpl") else {
                    fatalError("Failed to find depthToColorKernelImpl in Metal library")
                }
                self.pipelineState = try Self.metalDevice.makeComputePipelineState(function: function)
            } catch {
                fatalError("Failed to create Metal pipeline state: \(error)")
            }
        }
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            // Check if depth data is available
            guard let depthData: CVPixelBuffer = frame.sceneDepth?.depthMap else { return }
            
            // Get dimensions of the depth data
            let width = CVPixelBufferGetWidth(depthData)
            let height = CVPixelBufferGetHeight(depthData)
            
            // Create Metal textures for input and output
            var depthTexture: MTLTexture?
            var outputTexture: MTLTexture?
            
            // Create a Metal texture cache
            var textureCache: CVMetalTextureCache?
            CVMetalTextureCacheCreate(nil, nil, Self.metalDevice, nil, &textureCache)
            
            guard let textureCache = textureCache else {
                print("Failed to create texture cache")
                return
            }
            
            // Create a Metal texture from the depth data using texture cache
            var cvTextureOut: CVMetalTexture?
            let depthFormatDescription = CVPixelBufferGetPixelFormatType(depthData)
            
            CVMetalTextureCacheCreateTextureFromImage(
                kCFAllocatorDefault,
                textureCache,
                depthData,
                nil,
                .r32Float,
                width,
                height,
                0,
                &cvTextureOut
            )
            
            guard let cvTexture = cvTextureOut,
                  let depthTexture = CVMetalTextureGetTexture(cvTexture) else {
                print("Failed to create depth texture from pixel buffer")
                return
            }
            
            // Create output texture
            let outputDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba8Unorm,  // Changed to a more standard format
                width: width,
                height: height,
                mipmapped: false)
            outputDescriptor.usage = [.shaderWrite, .shaderRead]  // Added shaderRead for reading back the result
            
            outputTexture = Self.metalDevice.makeTexture(descriptor: outputDescriptor)
            
            guard let outputTexture = outputTexture else {
                print("Failed to create output texture")
                return
            }
            
            // Create command buffer and encoder
            guard let commandBuffer = Self.commandQueue.makeCommandBuffer(),
                  let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
                print("Failed to create command buffer or encoder")
                return
            }
            
            // Set up compute pipeline
            computeEncoder.setComputePipelineState(pipelineState)
            computeEncoder.setTexture(depthTexture, index: 0)
            computeEncoder.setTexture(outputTexture, index: 1)
            
            // Calculate thread groups
            let threadGroupSize = MTLSizeMake(16, 16, 1)
            let threadGroups = MTLSizeMake(
                (width + threadGroupSize.width - 1) / threadGroupSize.width,
                (height + threadGroupSize.height - 1) / threadGroupSize.height,
                1)
            
            // Dispatch threads
            computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
            computeEncoder.endEncoding()
            
            // Add completion handler
            commandBuffer.addCompletedHandler { [weak self] _ in
                // Create a CIImage from the output texture
                if let ciImage = CIImage(mtlTexture: outputTexture, options: [.colorSpace: CGColorSpaceCreateDeviceRGB()]) {
                    let context = CIContext()
                    if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                        DispatchQueue.main.async {
                            // Correct orientation to match camera feed
                            self?.parent.depthImage = self?.rotateImage(UIImage(cgImage: cgImage), orientation: .right)
                        }
                    }
                }
            }
            
            // Submit command buffer
            commandBuffer.commit()
        }
        
        // Rotates an image to match the camera feed orientation
        private func rotateImage(_ image: UIImage, orientation: UIImage.Orientation) -> UIImage {
            if let cgImage = image.cgImage {
                // First rotate the image
                let rotatedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: orientation)
                
                // Then flip it horizontally
                UIGraphicsBeginImageContextWithOptions(rotatedImage.size, false, rotatedImage.scale)
                let context = UIGraphicsGetCurrentContext()!
                
                // Flip the context horizontally
                context.translateBy(x: rotatedImage.size.width, y: 0)
                context.scaleBy(x: -1, y: 1)
                
                rotatedImage.draw(in: CGRect(origin: .zero, size: rotatedImage.size))
                let flippedImage = UIGraphicsGetImageFromCurrentImageContext()!
                UIGraphicsEndImageContext()
                
                return flippedImage
            }
            return image
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
