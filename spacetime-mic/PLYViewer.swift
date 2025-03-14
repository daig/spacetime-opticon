import SwiftUI
import ARKit
import SceneKit
import UniformTypeIdentifiers
import RealityKit

extension UTType {
    static var ply: UTType {
        UTType(filenameExtension: "ply")!
    }
}

struct PLYViewer: View {
    @State private var showFilePicker = false
    @State private var selectedPoints: [SIMD3<Float>]?
    
    var body: some View {
        ZStack {
            ARViewContainer(points: selectedPoints)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                Button(action: {
                    showFilePicker = true
                }) {
                    Text("Load PLY File")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $showFilePicker) {
            DocumentPicker { url in
                loadPLYFile(from: url)
            }
        }
    }
    
    private func loadPLYFile(from url: URL) {
        do {
            let contents = try String(contentsOf: url, encoding: .utf8)
            let points = parsePLYFile(contents)
            selectedPoints = points
        } catch {
            print("Error loading PLY file: \(error)")
        }
    }
    
    private func parsePLYFile(_ contents: String) -> [SIMD3<Float>] {
        var points: [SIMD3<Float>] = []
        let lines = contents.components(separatedBy: .newlines)
        var dataStartIndex = 0
        var numVertices = 0
        
        // Find where the vertex data begins and get number of vertices
        for (index, line) in lines.enumerated() {
            if line.contains("element vertex") {
                numVertices = Int(line.components(separatedBy: " ").last ?? "0") ?? 0
            }
            if line == "end_header" {
                dataStartIndex = index + 1
                break
            }
        }
        
        // Parse vertex data
        let endIndex = min(dataStartIndex + numVertices, lines.count)
        for i in dataStartIndex..<endIndex {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            
            let coordinates = line.split(separator: " ").compactMap { Float($0) }
            if coordinates.count >= 3 {
                points.append(SIMD3<Float>(coordinates[0], coordinates[1], coordinates[2]))
            }
        }
        
        return points
    }
}

struct ARViewContainer: UIViewRepresentable {
    let points: [SIMD3<Float>]?
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView(frame: .zero)
        arView.session.delegate = context.coordinator
        
        // Configure AR session
        let configuration = ARWorldTrackingConfiguration()
        arView.session.run(configuration)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Clear existing nodes
        uiView.scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }
        
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
        var parent: ARViewContainer
        
        init(_ parent: ARViewContainer) {
            self.parent = parent
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.ply])
        documentPicker.delegate = context.coordinator
        documentPicker.allowsMultipleSelection = false
        documentPicker.shouldShowFileExtensions = true
        return documentPicker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        
        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to access the file")
                return
            }
            
            // Make sure to release the security-scoped resource when finished
            defer { url.stopAccessingSecurityScopedResource() }
            
            onPick(url)
        }
    }
} 