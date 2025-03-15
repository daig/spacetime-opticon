import SwiftUI
import ARKit
import SceneKit
import UniformTypeIdentifiers
import RealityKit

extension UTType {
    static var ply: UTType {
        UTType(filenameExtension: "ply")!
    }
    
    static var plyVideo: UTType {
        // Register a more specific type with a custom extension
        UTType(exportedAs: "com.spacetime-mic.plyvideo", 
               conformingTo: .directory)
    }
}

struct PLYViewer: View {
    @State private var showFilePicker = false
    @State private var showDirectoryPicker = false
    @State private var selectedPoints: [SIMD3<Float>]?
    @State private var isPlayingPLYVideo = false
    @State private var plyVideoFrames: [[SIMD3<Float>]] = []
    @State private var currentFrameIndex = 0
    @State private var videoPlaybackTimer: Timer?
    
    var body: some View {
        ZStack {
            ARViewContainer(points: selectedPoints)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                if isPlayingPLYVideo {
                    HStack {
                        Button(action: {
                            stopPLYVideoPlayback()
                        }) {
                            Image(systemName: "stop.fill")
                                .foregroundColor(.red)
                                .padding()
                                .background(Color.white.opacity(0.7))
                                .clipShape(Circle())
                        }
                        
                        Text("Playing: Frame \(currentFrameIndex + 1) of \(plyVideoFrames.count)")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                    }
                    .padding(.top, 50)
                }
                
                Spacer()
                
                HStack(spacing: 20) {
                    Button(action: {
                        showFilePicker = true
                    }) {
                        Text("Load PLY File")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        // Use the document browser directly
                        openPLYVideoDirectoryPicker()
                    }) {
                        Text("Load PLY Video")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $showFilePicker) {
            DocumentPicker(contentTypes: [.ply]) { url in
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
    
    private func openPLYVideoDirectoryPicker() {
        // On iOS it's difficult to select directories in document picker
        // Let's use a simpler approach - list the document directory and show those options
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let fileManager = FileManager.default
                guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                    print("Could not access documents directory")
                    return
                }
                
                // Get list of directories and .bundle files in the Documents folder
                let contents = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: [.isDirectoryKey], options: [])
                
                // Filter for only directories and bundle files
                var plyVideoPaths: [URL] = []
                
                for url in contents {
                    let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
                    let isDirectory = resourceValues.isDirectory ?? false
                    
                    if isDirectory && url.lastPathComponent.contains("plyVideo") {
                        plyVideoPaths.append(url)
                    }
                }
                
                DispatchQueue.main.async {
                    if plyVideoPaths.isEmpty {
                        // No PLY videos found, show message
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootViewController = windowScene.windows.first?.rootViewController {
                            let alert = UIAlertController(
                                title: "No PLY Videos Found",
                                message: "No PLY video folders were found in your Documents directory. Record a PLY video first.",
                                preferredStyle: .alert
                            )
                            alert.addAction(UIAlertAction(title: "OK", style: .default))
                            rootViewController.present(alert, animated: true)
                        }
                    } else {
                        // Show list of available PLY videos
                        self.showPLYVideoSelectionMenu(videos: plyVideoPaths)
                    }
                }
            } catch {
                print("Error listing documents directory: \(error)")
                
                DispatchQueue.main.async {
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootViewController = windowScene.windows.first?.rootViewController {
                        let alert = UIAlertController(
                            title: "Error",
                            message: "Failed to access PLY video directories: \(error.localizedDescription)",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        rootViewController.present(alert, animated: true)
                    }
                }
            }
        }
    }
    
    private func showPLYVideoSelectionMenu(videos: [URL]) {
        guard !videos.isEmpty else { return }
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            
            let alert = UIAlertController(
                title: "Select PLY Video",
                message: "Choose a PLY video to play:",
                preferredStyle: .actionSheet
            )
            
            // Add an action for each video
            for video in videos {
                let name = video.lastPathComponent
                alert.addAction(UIAlertAction(title: name, style: .default) { _ in
                    self.loadPLYVideo(from: video)
                })
            }
            
            // Add cancel button
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            rootViewController.present(alert, animated: true)
        }
    }
    
    private func checkAndLoadPLYVideoSource(_ url: URL) {
        // This function is no longer needed since we're using a direct selection approach
        verifyAndLoadPLYVideoDirectory(url)
    }
    
    private func verifyAndLoadPLYVideoDirectory(_ url: URL) {
        // Check if this directory contains PLY files and potentially a metadata file
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Check if this directory contains PLY files
                let fileManager = FileManager.default
                let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
                let plyFiles = contents.filter { $0.pathExtension.lowercased() == "ply" }
                
                if !plyFiles.isEmpty || url.lastPathComponent.contains("plyVideo") {
                    // Looks like a PLY video directory, load it
                    self.loadPLYVideo(from: url)
                } else {
                    // Not a PLY video directory
                    DispatchQueue.main.async {
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootViewController = windowScene.windows.first?.rootViewController {
                            let alert = UIAlertController(
                                title: "Invalid Directory",
                                message: "The selected directory does not appear to contain PLY video files.",
                                preferredStyle: .alert
                            )
                            alert.addAction(UIAlertAction(title: "OK", style: .default))
                            rootViewController.present(alert, animated: true)
                        }
                    }
                }
            } catch {
                print("Error checking directory: \(error)")
                
                // Show error to user
                DispatchQueue.main.async {
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootViewController = windowScene.windows.first?.rootViewController {
                        let alert = UIAlertController(
                            title: "Error",
                            message: "Failed to access directory: \(error.localizedDescription)",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        rootViewController.present(alert, animated: true)
                    }
                }
            }
        }
    }
    
    private func loadPLYVideo(from bundleURL: URL) {
        print("Loading PLY video from: \(bundleURL.path)")
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Look for metadata file
                let metadataURL = bundleURL.appendingPathComponent("metadata.json")
                let metadataExists = FileManager.default.fileExists(atPath: metadataURL.path)
                
                // Read metadata if it exists
                var frameCount = 0
                var frameRate: Double = 1.0
                
                if metadataExists {
                    print("Found metadata file")
                    let metadataData = try Data(contentsOf: metadataURL)
                    if let metadata = try JSONSerialization.jsonObject(with: metadataData) as? [String: Any] {
                        frameCount = metadata["frameCount"] as? Int ?? 0
                        frameRate = metadata["frameRate"] as? Double ?? 1.0
                        print("Metadata: frameCount=\(frameCount), frameRate=\(frameRate)")
                    }
                } else {
                    print("No metadata file found")
                }
                
                // Find PLY files in the bundle
                let fileManager = FileManager.default
                let contents = try fileManager.contentsOfDirectory(at: bundleURL, includingPropertiesForKeys: nil, options: [])
                let plyFiles = contents.filter { $0.pathExtension.lowercased() == "ply" }
                    .sorted { $0.lastPathComponent < $1.lastPathComponent }
                
                print("Found \(plyFiles.count) PLY files")
                
                if plyFiles.isEmpty {
                    print("No PLY files found in the directory")
                    DispatchQueue.main.async {
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootViewController = windowScene.windows.first?.rootViewController {
                            let alert = UIAlertController(
                                title: "Error",
                                message: "No PLY files found in the selected directory.",
                                preferredStyle: .alert
                            )
                            alert.addAction(UIAlertAction(title: "OK", style: .default))
                            rootViewController.present(alert, animated: true)
                        }
                    }
                    return
                }
                
                // If no metadata, use the count of PLY files
                if frameCount == 0 {
                    frameCount = plyFiles.count
                }
                
                // Load all frames
                var frames: [[SIMD3<Float>]] = []
                for (index, plyFile) in plyFiles.enumerated() {
                    print("Loading PLY file \(index+1)/\(plyFiles.count): \(plyFile.lastPathComponent)")
                    let contents = try String(contentsOf: plyFile, encoding: .utf8)
                    let points = parsePLYFile(contents)
                    print("  - Loaded \(points.count) points")
                    frames.append(points)
                }
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    print("Loaded \(frames.count) frames, starting playback")
                    self.plyVideoFrames = frames
                    self.startPLYVideoPlayback(frameRate: frameRate)
                }
                
            } catch {
                print("Error loading PLY video: \(error)")
                
                DispatchQueue.main.async {
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootViewController = windowScene.windows.first?.rootViewController {
                        let alert = UIAlertController(
                            title: "Error",
                            message: "Failed to load PLY video: \(error.localizedDescription)",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        rootViewController.present(alert, animated: true)
                    }
                }
            }
        }
    }
    
    private func startPLYVideoPlayback(frameRate: Double) {
        guard !plyVideoFrames.isEmpty else { return }
        
        // Reset to first frame
        currentFrameIndex = 0
        selectedPoints = plyVideoFrames.first
        isPlayingPLYVideo = true
        
        // Set up timer for playback (default to 1 frame per second)
        let interval = 1.0 / frameRate
        videoPlaybackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            self.advanceToNextFrame()
        }
    }
    
    private func advanceToNextFrame() {
        guard !plyVideoFrames.isEmpty else { return }
        
        // Move to next frame
        currentFrameIndex = (currentFrameIndex + 1) % plyVideoFrames.count
        
        // Show the frame
        selectedPoints = plyVideoFrames[currentFrameIndex]
        
        // If we've completed a loop, stop playback
        if currentFrameIndex == 0 {
            stopPLYVideoPlayback()
        }
    }
    
    private func stopPLYVideoPlayback() {
        videoPlaybackTimer?.invalidate()
        videoPlaybackTimer = nil
        isPlayingPLYVideo = false
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

// Modified DocumentPicker to accept content types
struct DocumentPicker: UIViewControllerRepresentable {
    let contentTypes: [UTType]
    let onPick: (URL) -> Void
    
    init(contentTypes: [UTType] = [.ply], onPick: @escaping (URL) -> Void) {
        self.contentTypes = contentTypes
        self.onPick = onPick
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes)
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

// Helper class for presenting document picker modally
class DocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
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