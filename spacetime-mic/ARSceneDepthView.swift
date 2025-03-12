import SwiftUI
import AVFoundation
import ARKit
import RealityKit
import UIKit
import Metal
import MetalKit

struct ARSceneDepthView: UIViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var depthImage: UIImage?
    @Binding var pointCloud: [SIMD3<Float>]? // Binding for point cloud

    class Coordinator: NSObject, ARSessionDelegate {
        var parent: ARSceneDepthView
        let device: MTLDevice
        let commandQueue: MTLCommandQueue
        let pipelineState: MTLComputePipelineState
        var textureCache: CVMetalTextureCache?

        static let ciContext = CIContext()
        static let colorKernel: CIColorKernel = {
            guard let url = Bundle.main.url(forResource: "default", withExtension: "metallib"),
                  let data = try? Data(contentsOf: url),
                  let kernel = try? CIColorKernel(functionName: "depthToColor", fromMetalLibraryData: data) else {
                fatalError("Failed to load Metal library or create CIColorKernel")
            }
            return kernel
        }()

        init(_ parent: ARSceneDepthView) {
            self.parent = parent
            self.device = MTLCreateSystemDefaultDevice()!
            self.commandQueue = device.makeCommandQueue()!
            let library = device.makeDefaultLibrary()!
            let function = library.makeFunction(name: "generatePoints")!
            self.pipelineState = try! device.makeComputePipelineState(function: function)
            CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
        }

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            guard let depthData = frame.sceneDepth?.depthMap else { return }

            // Generate point cloud using Metal
            let points = generatePointCloud(from: depthData, camera: frame.camera)

            // Generate depth image (existing functionality)
            let depthCIImage = CIImage(cvPixelBuffer: depthData)
            if let outputImage = Coordinator.colorKernel.apply(extent: depthCIImage.extent, arguments: [depthCIImage]),
               let cgImage = Coordinator.ciContext.createCGImage(outputImage, from: outputImage.extent) {
                let uiImage = UIImage(cgImage: cgImage)
                DispatchQueue.main.async {
                    self.parent.depthImage = self.rotateImage(uiImage, orientation: .right)
                    self.parent.pointCloud = points // Update point cloud on main thread
                }
            }
        }

        // Helper function to scale intrinsics for the depth map
        private func scaledIntrinsics(for depthMap: CVPixelBuffer, camera: ARCamera) -> (fx: Float, fy: Float, cx: Float, cy: Float) {
            let depthWidth = Float(CVPixelBufferGetWidth(depthMap))
            let depthHeight = Float(CVPixelBufferGetHeight(depthMap))
            let colorWidth = Float(camera.imageResolution.width)
            let colorHeight = Float(camera.imageResolution.height)
            let intrinsics = camera.intrinsics

            let scaleX = depthWidth / colorWidth
            let scaleY = depthHeight / colorHeight

            let fx = intrinsics[0][0] * scaleX // Focal length x
            let fy = intrinsics[1][1] * scaleY // Focal length y
            let cx = intrinsics[2][0] * scaleX // Principal point x
            let cy = intrinsics[2][1] * scaleY // Principal point y

            return (fx, fy, cx, cy)
        }

        // Generate point cloud from depth map using Metal
        private func generatePointCloud(from depthMap: CVPixelBuffer, camera: ARCamera) -> [SIMD3<Float>] {
            // Check that the depth map is in the expected Float32 format
            guard CVPixelBufferGetPixelFormatType(depthMap) == kCVPixelFormatType_DepthFloat32 else {
                print("Error: Depth map is not in Float32 format")
                return []
            }

            // Get the scaled camera intrinsics
            let (fx, fy, cx, cy) = scaledIntrinsics(for: depthMap, camera: camera)
            
            let width = CVPixelBufferGetWidth(depthMap)
            let height = CVPixelBufferGetHeight(depthMap)
            
            // Create Metal texture from CVPixelBuffer
            var cvMetalTexture: CVMetalTexture?
            let result = CVMetalTextureCacheCreateTextureFromImage(
                nil,
                textureCache!,
                depthMap,
                nil,
                .r32Float,
                width,
                height,
                0,
                &cvMetalTexture
            )
            guard result == kCVReturnSuccess, let cvTexture = cvMetalTexture else {
                print("Failed to create Metal texture from depth map")
                return []
            }
            let depthTexture = CVMetalTextureGetTexture(cvTexture)!
            
            // Prepare intrinsics buffer
            let intrinsicsVector = SIMD4<Float>(fx, fy, cx, cy)
            let intrinsicsBuffer = withUnsafePointer(to: intrinsicsVector) { ptr in
                device.makeBuffer(bytes: ptr, length: MemoryLayout<SIMD4<Float>>.size, options: .storageModeShared)
            }
            
            // Prepare counter buffer
            var counter: UInt32 = 0
            let counterBuffer = device.makeBuffer(bytes: &counter, length: MemoryLayout<UInt32>.size, options: .storageModeShared)!
            
            // Prepare points buffer
            let maxPoints = width * height
            let pointsBuffer = device.makeBuffer(length: maxPoints * MemoryLayout<SIMD3<Float>>.size, options: .storageModeShared)!
            
            // Set up command buffer and encoder
            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let encoder = commandBuffer.makeComputeCommandEncoder() else { return [] }
            
            encoder.setComputePipelineState(pipelineState)
            encoder.setTexture(depthTexture, index: 0)
            encoder.setBuffer(counterBuffer, offset: 0, index: 0)
            encoder.setBuffer(pointsBuffer, offset: 0, index: 1)
            encoder.setBuffer(intrinsicsBuffer, offset: 0, index: 2)
            
            let threadsPerThreadgroup = MTLSize(width: 16, height: 16, depth: 1)
            let threadgroups = MTLSize(
                width: (width + 15) / 16,
                height: (height + 15) / 16,
                depth: 1
            )
            encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
            encoder.endEncoding()
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            
            // Read the counter and points
            let count = counterBuffer.contents().assumingMemoryBound(to: UInt32.self).pointee
            let pointsPointer = pointsBuffer.contents().assumingMemoryBound(to: SIMD3<Float>.self)
            let pointsArray = Array(UnsafeBufferPointer(start: pointsPointer, count: Int(count)))
            
            return pointsArray
        }

        private func rotateImage(_ image: UIImage, orientation: UIImage.Orientation) -> UIImage {
            guard let cgImage = image.cgImage else { return image }
            return UIImage(cgImage: cgImage, scale: image.scale, orientation: orientation)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let config = ARWorldTrackingConfiguration()
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        } else {
            print("Scene depth is not supported on this device")
        }
        arView.session.delegate = context.coordinator
        arView.session.run(config)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}
