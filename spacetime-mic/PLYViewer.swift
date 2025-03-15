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
    
    static var drcPlyVideo: UTType {
        // Register a type for Draco-encoded PLY video bundles
        UTType(exportedAs: "com.spacetime-mic.drcplyvideo", 
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
    @State private var isDracoEncodedVideo = false
    
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
                        
                        Text("Playing: Frame \(currentFrameIndex + 1) of \(plyVideoFrames.count)\(isDracoEncodedVideo ? " (Draco)" : "")")
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
                        // Load Draco PLY video bundles
                        openDracoPLYVideoDirectoryPicker()
                    }) {
                        Text("Load PLY Video")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.purple)
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
        // Regular PLY video functionality removed in favor of more efficient Draco-encoded format
    }
    
    private func verifyAndLoadPLYVideoDirectory(_ url: URL) {
        // Regular PLY video functionality removed in favor of more efficient Draco-encoded format
    }
    
    private func loadPLYVideo(from bundleURL: URL) {
        // Regular PLY video functionality removed in favor of more efficient Draco-encoded format
    }
    
    private func startPLYVideoPlayback(frameRate: Double) {
        guard !plyVideoFrames.isEmpty else { return }
        
        // Create a fresh copy of each frame to ensure SwiftUI sees changes
        var freshFrames: [[SIMD3<Float>]] = []
        for frame in plyVideoFrames {
            // Force create a new array for each frame
            let freshFrame = frame.map { SIMD3<Float>($0.x, $0.y, $0.z) }
            freshFrames.append(freshFrame)
        }
        
        // Use the fresh frames for playback
        plyVideoFrames = freshFrames
        
        // Reset to first frame
        currentFrameIndex = 0
        selectedPoints = plyVideoFrames.first
        isPlayingPLYVideo = true
        
        // Set up timer for playback (default to 1 frame per second)
        let interval = 1.0 / frameRate
        videoPlaybackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            // No need for weak self since PLYViewer is a struct (value type)
            self.advanceToNextFrame()
        }
    }
    
    private func advanceToNextFrame() {
        guard !plyVideoFrames.isEmpty else { return }
        
        // Store previous frame's point count for comparison
        let previousFrameIndex = currentFrameIndex
        let previousPointCount = plyVideoFrames[previousFrameIndex].count
        
        // Move to next frame
        currentFrameIndex = (currentFrameIndex + 1) % plyVideoFrames.count
        
        // Get current frame
        let currentFramePoints = plyVideoFrames[currentFrameIndex]
        let currentPointCount = currentFramePoints.count
        
        print("Frame transition: \(previousFrameIndex) -> \(currentFrameIndex)")
        print("Point counts: \(previousPointCount) -> \(currentPointCount)")
        
        // Check if frames are identical (might explain updating every 2 frames)
        if previousPointCount == currentPointCount {
            // Sample a few points to check for similarity (first, middle, last point)
            let prevPoints = plyVideoFrames[previousFrameIndex]
            let currPoints = currentFramePoints
            
            if !prevPoints.isEmpty && !currPoints.isEmpty {
                let first = prevPoints[0] == currPoints[0]
                
                let midIndex = prevPoints.count / 2
                let middle = midIndex < prevPoints.count ? prevPoints[midIndex] == currPoints[midIndex] : false
                
                let lastIndex = prevPoints.count - 1
                let last = lastIndex >= 0 ? prevPoints[lastIndex] == currPoints[lastIndex] : false
                
                print("Sample points identical? First: \(first), Middle: \(middle), Last: \(last)")
                
                if first && middle && last {
                    print("WARNING: Adjacent frames appear to be identical!")
                }
            }
        }
        
        // Create a fresh copy of the frame to ensure SwiftUI detects the change
        // This forces SwiftUI to see it as a brand new array
        let freshFrame = currentFramePoints.map { SIMD3<Float>($0.x, $0.y, $0.z) }
        
        // Update state with the fresh frame
        // This ensures that even if the frame data is the same,
        // SwiftUI will see it as a new array and update the view
        selectedPoints = freshFrame
        
        // Print a memory address to check if the reference is changing
        print("Setting selectedPoints to \(Unmanaged.passUnretained(freshFrame as AnyObject).toOpaque())")
        
        // If we've completed a loop, stop playback
        if currentFrameIndex == 0 {
            stopPLYVideoPlayback()
        }
    }
    
    private func stopPLYVideoPlayback() {
        videoPlaybackTimer?.invalidate()
        videoPlaybackTimer = nil
        isPlayingPLYVideo = false
        isDracoEncodedVideo = false
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
    
    // New method to open picker for Draco-encoded PLY video bundles
    private func openDracoPLYVideoDirectoryPicker() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let fileManager = FileManager.default
                guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                    print("Could not access documents directory")
                    return
                }
                
                // Get list of directories in the Documents folder
                let contents = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: [.isDirectoryKey], options: [])
                
                // Filter for only directories that match our naming pattern for Draco PLY video bundles
                var dracoPLYVideoPaths: [URL] = []
                
                for url in contents {
                    let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
                    let isDirectory = resourceValues.isDirectory ?? false
                    
                    if isDirectory && url.lastPathComponent.contains(".drc.bundle") {
                        dracoPLYVideoPaths.append(url)
                    }
                }
                
                DispatchQueue.main.async {
                    if dracoPLYVideoPaths.isEmpty {
                        self.showAlert(title: "No Draco PLY Videos Found", 
                                       message: "No Draco-encoded PLY video folders were found in your Documents directory. Record a PLY video first.")
                    } else {
                        // Show list of available Draco PLY videos
                        self.showDracoPLYVideoSelectionMenu(videos: dracoPLYVideoPaths)
                    }
                }
            } catch {
                print("Error listing documents directory: \(error)")
                
                DispatchQueue.main.async {
                    self.showAlert(title: "Error",
                                   message: "Failed to access Draco PLY video directories: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // Helper method to show alerts with platform-specific implementations
    private func showAlert(title: String, message: String) {
        #if os(iOS)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            let alert = UIAlertController(
                title: title,
                message: message,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            rootViewController.present(alert, animated: true)
        }
        #elseif os(macOS)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
        #endif
    }
    
    // New method to show a menu of available Draco PLY videos
    private func showDracoPLYVideoSelectionMenu(videos: [URL]) {
        guard !videos.isEmpty else { return }
        
        #if os(iOS)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            
            let alert = UIAlertController(
                title: "Select Draco PLY Video",
                message: "Choose a Draco-encoded PLY video to play:",
                preferredStyle: .actionSheet
            )
            
            // Add an action for each video
            for video in videos {
                let name = video.lastPathComponent
                alert.addAction(UIAlertAction(title: name, style: .default) { _ in
                    self.loadDracoPLYVideo(from: video)
                })
            }
            
            // Add cancel button
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            rootViewController.present(alert, animated: true)
        }
        #elseif os(macOS)
        // On macOS create a panel or use NSPopover to display options
        let alert = NSAlert()
        alert.messageText = "Select Draco PLY Video"
        alert.informativeText = "Choose a Draco-encoded PLY video to play:"
        
        // Create a popup button with options
        let popupButton = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        for video in videos {
            popupButton.addItem(withTitle: video.lastPathComponent)
        }
        alert.accessoryView = popupButton
        
        // Add buttons
        alert.addButton(withTitle: "Load")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn && popupButton.indexOfSelectedItem >= 0 {
            // User clicked "Load"
            let selectedIndex = popupButton.indexOfSelectedItem
            let selectedVideo = videos[selectedIndex]
            self.loadDracoPLYVideo(from: selectedVideo)
        }
        #endif
    }
    
    // Method to load and play a Draco-encoded PLY video
    private func loadDracoPLYVideo(from bundleURL: URL) {
        print("Loading Draco PLY video from: \(bundleURL.path)")
        
        // Create a VideoRecordingView to use its Draco decoding functionality
        let videoRecordingView = VideoRecordingView()
        
        // Load the Draco-encoded frames
        videoRecordingView.loadDracoPLYVideoBundle(from: bundleURL) { frames in
            if let frames = frames, !frames.isEmpty {
                print("Successfully loaded \(frames.count) Draco-encoded frames")
                self.plyVideoFrames = frames
                self.isDracoEncodedVideo = true
                
                // Find metadata file to get frame rate
                let metadataURL = bundleURL.appendingPathComponent("metadata.json")
                var frameRate: Double = 1.0
                
                // Safely read metadata without throwing
                if let metadataData = try? Data(contentsOf: metadataURL),
                   let metadata = try? JSONSerialization.jsonObject(with: metadataData) as? [String: Any],
                   let rate = metadata["frameRate"] as? Double {
                    frameRate = rate
                }
                
                // Start playback
                self.startPLYVideoPlayback(frameRate: frameRate)
            } else {
                // Show error to user
                DispatchQueue.main.async {
                    self.showAlert(title: "Error",
                                   message: "Failed to load Draco PLY video from \(bundleURL.lastPathComponent)")
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
        
        // Create a persistent point cloud node that we'll update
        let pointCloudNode = SCNNode()
        pointCloudNode.name = "pointCloudNode"
        sceneView.scene?.rootNode.addChildNode(pointCloudNode)
        
        // Create a persistent camera node
        let cameraNode = SCNNode()
        cameraNode.name = "cameraNode"
        cameraNode.camera = SCNCamera()
        sceneView.scene?.rootNode.addChildNode(cameraNode)
        sceneView.pointOfView = cameraNode
        
        #if os(iOS)
        sceneView.scene?.background.contents = UIColor.black
        #else
        sceneView.scene?.background.contents = NSColor.black
        #endif
        
        return sceneView
    }
    
    func updateUIView(_ sceneView: SCNView, context: Context) {
        guard let points = points, !points.isEmpty else { return }
        
        // Log point cloud update request
        print("🔄 SceneKit view update requested with \(points.count) points at \(Unmanaged.passUnretained(points as AnyObject).toOpaque())")
        
        // Get or create the point cloud node
        let pointCloudNode: SCNNode
        if let existingNode = sceneView.scene?.rootNode.childNode(withName: "pointCloudNode", recursively: false) {
            // Remove any existing geometry
            pointCloudNode = existingNode
            pointCloudNode.geometry = nil
        } else {
            // Create the node if it doesn't exist (shouldn't happen)
            pointCloudNode = SCNNode()
            pointCloudNode.name = "pointCloudNode"
            sceneView.scene?.rootNode.addChildNode(pointCloudNode)
        }
        
        // Create point cloud geometry
        let vertices = points.map { point in
            // Keep original coordinates - preserve the perspective
            SCNVector3(point.x, point.y, point.z)
        }
        
        // Update the point cloud geometry
        updatePointCloudGeometry(node: pointCloudNode, from: vertices)
        
        // Check if we need to initialize the camera
        if let cameraNode = sceneView.scene?.rootNode.childNode(withName: "cameraNode", recursively: false),
           cameraNode.camera != nil,
           // Only set up camera initially or if it hasn't been positioned yet
           (cameraNode.position.x == 0 && cameraNode.position.y == 0 && cameraNode.position.z == 0) {
            setupInitialCamera(cameraNode: cameraNode, points: vertices)
        }
        
        print("✅ Updated point cloud with \(points.count) points")
    }
    
    private func updatePointCloudGeometry(node: SCNNode, from vertices: [SCNVector3]) {
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
        
        // Set the geometry on the node
        node.geometry = geometry
        
        // Apply rotation to correct the orientation
        // Rotate 90 degrees clockwise around the Z-axis to counter the counter-clockwise rotation
        node.eulerAngles = SCNVector3(0, 0, -Float.pi/2)
        
        // Apply scale to flip the Z axis to correct backwards appearance
        node.scale = SCNVector3(1, 1, -1)
    }
    
    private func createPointCloudNode(from vertices: [SCNVector3]) -> SCNNode {
        // This method is kept for compatibility as a wrapper to our new function
        let node = SCNNode()
        updatePointCloudGeometry(node: node, from: vertices)
        return node
    }
    
    private func setupInitialCamera(cameraNode: SCNNode, points: [SCNVector3]) {
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
        
        // Position camera at a distance from the point cloud
        cameraNode.position = SCNVector3(centerX, centerY, centerZ + maxDimension * 1.5)
        
        // Look directly at the center of the point cloud
        cameraNode.look(at: SCNVector3(centerX, centerY, centerZ))
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
}
