import SwiftUI
import SceneKit
import UniformTypeIdentifiers
import RealityKit

#if os(iOS)
import UIKit
typealias PlatformColor = UIColor
typealias PlatformViewController = UIViewController
typealias PlatformGestureRecognizer = UIGestureRecognizer
typealias PlatformPanGestureRecognizer = UIPanGestureRecognizer
typealias PlatformPinchGestureRecognizer = UIPinchGestureRecognizer
typealias PlatformAlertController = UIAlertController
typealias PlatformAlertAction = UIAlertAction
#elseif os(macOS)
import AppKit
typealias PlatformColor = NSColor
typealias PlatformViewController = NSViewController
typealias PlatformGestureRecognizer = NSGestureRecognizer
typealias PlatformPanGestureRecognizer = NSPanGestureRecognizer
typealias PlatformPinchGestureRecognizer = NSMagnificationGestureRecognizer
typealias PlatformAlertController = NSAlert
typealias PlatformAlertAction = NSAlert.Button
#endif

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
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var plyVideoPaths: [URL] = []
    @State private var dracoFiles: [URL] = []
    @State private var showPLYVideoOptions = false
    @State private var showDracoFileOptions = false
    
    var body: some View {
        ZStack {
            SceneKitViewContainer(points: selectedPoints)
            
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
                    
                    Button(action: {
                        showDracoFilePicker()
                    }) {
                        Text("Load Draco File")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.orange)
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
    
    // Function to show the picker for Draco files
    private func showDracoFilePicker() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let fileManager = FileManager.default
                guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                    print("Could not access documents directory")
                    return
                }
                
                // Get list of .drc files in the Documents folder
                let contents = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: [.isRegularFileKey], options: [])
                
                // Filter for only .drc files
                let dracoFiles = contents.filter { $0.pathExtension.lowercased() == "drc" }
                
                DispatchQueue.main.async {
                    if dracoFiles.isEmpty {
                        // No Draco files found, show message
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootViewController = windowScene.windows.first?.rootViewController {
                            let alert = UIAlertController(
                                title: "No Draco Files Found",
                                message: "No Draco files were found in your Documents directory. Create a Draco file first.",
                                preferredStyle: .alert
                            )
                            alert.addAction(UIAlertAction(title: "OK", style: .default))
                            rootViewController.present(alert, animated: true)
                        }
                    } else {
                        // Show list of available Draco files
                        self.showDracoFileSelectionMenu(files: dracoFiles)
                    }
                }
            } catch {
                print("Error listing documents directory: \(error)")
                
                DispatchQueue.main.async {
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootViewController = windowScene.windows.first?.rootViewController {
                        let alert = UIAlertController(
                            title: "Error",
                            message: "Failed to access Draco files: \(error.localizedDescription)",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        rootViewController.present(alert, animated: true)
                    }
                }
            }
        }
    }
    
    // Function to display a menu with available Draco files
    private func showDracoFileSelectionMenu(files: [URL]) {
        guard !files.isEmpty else { return }
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            
            let alert = UIAlertController(
                title: "Select Draco File",
                message: "Choose a Draco file to load:",
                preferredStyle: .actionSheet
            )
            
            // Add an action for each file
            for file in files {
                let name = file.lastPathComponent
                alert.addAction(UIAlertAction(title: name, style: .default) { _ in
                    self.loadDracoFile(from: file)
                })
            }
            
            // Add cancel button
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            rootViewController.present(alert, animated: true)
        }
    }
    
    // Function to load a Draco file and display the points
    private func loadDracoFile(from url: URL) {
        // Define a class to hold persistent references to objects
        // This ensures our memory stays alive throughout the whole operation
        class DecoderContext {
            let data: Data
            let decoder = DracoDecoder()
            var pointCloud: DracoPointCloud?
            var positionData: Data?
            
            init(data: Data) {
                self.data = data
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Create a separate autorelease pool for this work
            autoreleasepool {
                do {
                    // First verify the file exists and is readable
                    let originalData = try Data(contentsOf: url)
                    print("[Draco] Successfully read file: \(url.lastPathComponent), size: \(originalData.count) bytes")
                    
                    // Create our context object to hold strong references
                    let context = DecoderContext(data: originalData)
                    
                    // Step 1: Create a VideoRecordingView to use its helper methods
                    // This is safer as it's already working in other parts of the app
                    let videoRecordingView = VideoRecordingView()
                    print("[Draco] Created VideoRecordingView for file loading")
                    
                    // Step 2: Use the VideoRecordingView's established method to load the file
                    print("[Draco] Attempting to load points from file...")
                    guard let points = videoRecordingView.loadDracoPointCloudFromFile(url: url) else {
                        throw NSError(domain: "DracoDecoding", code: 1, 
                                    userInfo: [NSLocalizedDescriptionKey: "Failed to load Draco file (null result)"])
                    }
                    
                    // Step 3: Make a copy of the points array to ensure memory safety
                    let pointsCopy = Array(points)
                    print("[Draco] Successfully loaded \(pointsCopy.count) points")
                    
                    // Send the points to the main thread
                    DispatchQueue.main.async {
                        print("[Draco] Updating UI with \(pointsCopy.count) points")
                        self.selectedPoints = pointsCopy
                        
                        // Show success message
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                            let rootViewController = windowScene.windows.first?.rootViewController {
                            let alert = UIAlertController(
                                title: "Draco File Loaded",
                                message: "Loaded \(pointsCopy.count) points from \(url.lastPathComponent)",
                                preferredStyle: .alert
                            )
                            alert.addAction(UIAlertAction(title: "OK", style: .default))
                            rootViewController.present(alert, animated: true)
                        }
                    }
                } catch {
                    print("[Draco] Error loading file: \(error)")
                    
                    DispatchQueue.main.async {
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootViewController = windowScene.windows.first?.rootViewController {
                            let alert = UIAlertController(
                                title: "Error",
                                message: "Failed to load Draco file: \(url.lastPathComponent)\nError: \(error.localizedDescription)",
                                preferredStyle: .alert
                            )
                            alert.addAction(UIAlertAction(title: "OK", style: .default))
                            rootViewController.present(alert, animated: true)
                        }
                    }
                }
            }
        }
    }
}

// New SceneKit view container that replaces AR view
struct SceneKitViewContainer: UIViewRepresentable {
    let points: [SIMD3<Float>]?
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView(frame: .zero)
        sceneView.backgroundColor = .black
        sceneView.scene = SCNScene()
        sceneView.allowsCameraControl = true // Built-in rotation and pan controls
        sceneView.autoenablesDefaultLighting = true
        
        #if os(iOS)
        sceneView.scene?.background.contents = UIColor.black
        #else
        sceneView.scene?.background.contents = NSColor.black
        #endif
        
        return sceneView
    }
    
    func updateUIView(_ sceneView: SCNView, context: Context) {
        // Clear existing nodes
        sceneView.scene?.rootNode.childNodes.forEach { $0.removeFromParentNode() }
        
        if let points = points, !points.isEmpty {
            // Create point cloud geometry
            // Adjust coordinate mapping to match iOS camera coordinate system
            // This ensures we maintain the exact perspective from capture
            let vertices = points.map { point in
                // Keep original coordinates - preserve the perspective
                SCNVector3(point.x, point.y, point.z)
            }
            
            let node = createPointCloudNode(from: vertices)
            
            // Add to scene
            sceneView.scene?.rootNode.addChildNode(node)
            
            // Set up camera
            setupCamera(for: sceneView, points: vertices)
            
            print("Added point cloud with \(points.count) points")
        }
    }
    
    private func createPointCloudNode(from vertices: [SCNVector3]) -> SCNNode {
        // Create geometry source from vertices
        let source = SCNGeometrySource(vertices: vertices)
        
        // Create indices
        let indices = (0..<vertices.count).map { UInt32($0) }
        let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<UInt32>.size)
        
        // Create geometry element for points
        let element = SCNGeometryElement(
            data: indexData,
            primitiveType: .point,
            primitiveCount: vertices.count,
            bytesPerIndex: MemoryLayout<UInt32>.size
        )
        
        // Create geometry
        let geometry = SCNGeometry(sources: [source], elements: [element])
        
        // Create material
        let material = SCNMaterial()
        
        #if os(iOS)
        material.diffuse.contents = UIColor.white
        #else
        material.diffuse.contents = NSColor.white
        #endif
        
        material.lightingModel = .constant
        
        // Set point size (make it larger for visibility)
        material.setValue(3.0, forKey: "pointSize")
        
        geometry.materials = [material]
        
        // Create node with geometry
        let node = SCNNode(geometry: geometry)
        
        // Apply rotation to correct the orientation
        // Rotate 90 degrees clockwise around the Z-axis to counter the counter-clockwise rotation
        node.eulerAngles = SCNVector3(0, 0, -Float.pi/2)
        
        // Apply scale to flip the Z axis to correct backwards appearance
        node.scale = SCNVector3(1, 1, -1)
        
        return node
    }
    
    private func setupCamera(for sceneView: SCNView, points: [SCNVector3]) {
        // Calculate bounding box
        var minX: Float = .greatestFiniteMagnitude
        var minY: Float = .greatestFiniteMagnitude
        var minZ: Float = .greatestFiniteMagnitude
        var maxX: Float = -.greatestFiniteMagnitude
        var maxY: Float = -.greatestFiniteMagnitude
        var maxZ: Float = -.greatestFiniteMagnitude
        
        for point in points {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
            minZ = min(minZ, point.z)
            maxZ = max(maxZ, point.z)
        }
        
        // Calculate center
        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2
        let centerZ = (minZ + maxZ) / 2
        
        // Calculate dimensions
        let sizeX = max(abs(maxX - minX), 0.1)
        let sizeY = max(abs(maxY - minY), 0.1)
        let sizeZ = max(abs(maxZ - minZ), 0.1)
        
        let maxDimension = max(max(sizeX, sizeY), sizeZ)
        
        // Create and position camera to match capture device perspective
        // We need to match exactly how the camera was positioned during capture
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        
        // Position camera at a distance from the point cloud
        // Use original camera position from depth capture - looking along negative Z axis
        cameraNode.position = SCNVector3(centerX, centerY, centerZ + maxDimension * 1.5)
        
        // Look directly at the center of the point cloud
        cameraNode.look(at: SCNVector3(centerX, centerY, centerZ))
        
        // Add to scene
        sceneView.scene?.rootNode.addChildNode(cameraNode)
        sceneView.pointOfView = cameraNode
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: SceneKitViewContainer
        
        init(_ parent: SceneKitViewContainer) {
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