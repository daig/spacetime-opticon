import SwiftUI
import ARKit
import SceneKit
import RealityKit

// Component for capturing depth data
struct ARDepthCaptureView: View {
    @Binding var points: [SIMD3<Float>]?
    
    var body: some View {
        ARDepthCaptureRepresentable(points: $points)
    }
}

struct ARDepthCaptureRepresentable: UIViewRepresentable {
    @Binding var points: [SIMD3<Float>]?
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView(frame: .zero)
        arView.delegate = context.coordinator
        arView.scene = SCNScene()
        arView.automaticallyUpdatesLighting = true
        
        // Configure AR session
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics = .sceneDepth
        
        // Set up debug options
        #if DEBUG
        arView.debugOptions = [.showFeaturePoints]
        #endif
        
        // Run the session with the configuration
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Update is handled by the coordinator
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, ARSCNViewDelegate {
        var parent: ARDepthCaptureRepresentable
        
        init(_ parent: ARDepthCaptureRepresentable) {
            self.parent = parent
        }
        
        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            guard let arView = renderer as? ARSCNView,
                  let frame = arView.session.currentFrame,
                  let depthData = frame.sceneDepth?.depthMap else {
                return
            }
            
            // Convert depth data to point cloud
            let points = convertDepthMapToPointCloud(depthMap: depthData, viewMatrix: frame.camera.viewMatrix(for: .portrait))
            DispatchQueue.main.async {
                self.parent.points = points
            }
        }
        
        private func convertDepthMapToPointCloud(depthMap: CVPixelBuffer, viewMatrix: simd_float4x4) -> [SIMD3<Float>] {
            var points: [SIMD3<Float>] = []
            let width = CVPixelBufferGetWidth(depthMap)
            let height = CVPixelBufferGetHeight(depthMap)
            
            CVPixelBufferLockBaseAddress(depthMap, .readOnly)
            let baseAddress = CVPixelBufferGetBaseAddress(depthMap)
            let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
            
            for y in stride(from: 0, to: height, by: 4) {
                for x in stride(from: 0, to: width, by: 4) {
                    let depthPointer = baseAddress?.advanced(by: y * bytesPerRow + x * MemoryLayout<Float32>.size)
                    let depth = depthPointer?.assumingMemoryBound(to: Float32.self).pointee ?? 0
                    
                    if depth > 0 {
                        let normalizedX = (2.0 * Float(x) / Float(width)) - 1.0
                        let normalizedY = 1.0 - (2.0 * Float(y) / Float(height))
                        
                        let point = SIMD3<Float>(normalizedX * depth, normalizedY * depth, -depth)
                        points.append(point)
                    }
                }
            }
            
            CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
            return points
        }
    }
}

// Component for displaying point clouds
struct ARPointCloudView: View {
    let points: [SIMD3<Float>]?
    
    var body: some View {
        ARPointCloudRepresentable(points: points)
    }
}

struct ARPointCloudRepresentable: UIViewRepresentable {
    let points: [SIMD3<Float>]?
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView(frame: .zero)
        arView.scene = SCNScene()
        arView.automaticallyUpdatesLighting = true
        
        // Basic configuration without AR tracking
        let configuration = ARWorldTrackingConfiguration()
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        // Set up camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0, 0)
        arView.scene.rootNode.addChildNode(cameraNode)
        
        // Add ambient light
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 1000
        arView.scene.rootNode.addChildNode(ambientLight)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Clear existing nodes except camera and lights
        uiView.scene.rootNode.childNodes.forEach { node in
            if node.camera == nil && node.light == nil {
                node.removeFromParentNode()
            }
        }
        
        if let points = points {
            // Create point cloud geometry
            let vertices = points.map { SCNVector3($0.x, $0.y, $0.z) }
            let geometry = createPointCloudGeometry(from: vertices)
            
            // Create and add node
            let node = SCNNode(geometry: geometry)
            uiView.scene.rootNode.addChildNode(node)
            
            // Position the point cloud in front of the camera
            node.position = SCNVector3(0, 0, -1)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func createPointCloudGeometry(from vertices: [SCNVector3]) -> SCNGeometry {
        let source = SCNGeometrySource(vertices: vertices)
        
        // Create array of indices and convert to Data
        let indices = (0..<vertices.count).map { UInt32($0) }
        let data = Data(bytes: indices, count: indices.count * MemoryLayout<UInt32>.size)
        
        let element = SCNGeometryElement(data: data,
                                       primitiveType: .point,
                                       primitiveCount: vertices.count,
                                       bytesPerIndex: MemoryLayout<UInt32>.size)
        
        let geometry = SCNGeometry(sources: [source], elements: [element])
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.white
        material.setValue(5.0, forKey: "pointSize")
        geometry.materials = [material]
        
        return geometry
    }
    
    class Coordinator: NSObject, ARSessionDelegate {
        var parent: ARPointCloudRepresentable
        
        init(_ parent: ARPointCloudRepresentable) {
            self.parent = parent
        }
    }
} 