//
//  VideoRecordingView+PLY.swift
//  spacetime-mic
//
//  Created by David Girardo on 3/12/25.
//

import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// No need to import spacetime_mic as we're already within it
// The bridging header brings in the Draco wrappers to the entire project

extension VideoRecordingView {
    private func pointCloudToPLY(points: [SIMD3<Float>]) -> String {
        let header = """
        ply
        format ascii 1.0
        element vertex \(points.count)
        property float x
        property float y
        property float z
        end_header
        """
        let pointsString = points.map { "\($0.x) \($0.y) \($0.z)" }.joined(separator: "\n")
        return header + "\n" + pointsString
    }
    
    func savePointCloudToFile(points: [SIMD3<Float>]) {
        DispatchQueue.global(qos: .background).async {
            let plyString = pointCloudToPLY(points: points)
            let fileManager = FileManager.default
            if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                let timestamp = dateFormatter.string(from: Date())
                let fileName = "pointCloud_\(timestamp).ply"
                let fileURL = documentsDirectory.appendingPathComponent(fileName)
                do {
                    try plyString.write(to: fileURL, atomically: true, encoding: .utf8)
                    print("Point cloud saved to \(fileURL)")
                } catch {
                    print("Error saving point cloud: \(error)")
                }
            }
        }
    }
    
    func savePointCloudToDracoFile(points: [SIMD3<Float>]) {
        DispatchQueue.global(qos: .background).async {
            let fileManager = FileManager.default
            guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("Could not access documents directory")
                return
            }
            
            // Create a Draco point cloud object
            let pointCloud = DracoPointCloud()
            
            // Set the number of points
            pointCloud.setNumPoints(points.count)
            
            // Add a position attribute (GeometryAttribute::POSITION = 0, DataType::DT_FLOAT32 = 9)
            // 3 components (x,y,z), not normalized
            let positionAttId = pointCloud.addAttribute(withType: 0, dataType: 9, numComponents: 3, normalized: false)
            
            // Convert our SIMD3<Float> array to raw data
            // We need to pack the data as a continuous array of floats: [x1,y1,z1,x2,y2,z2,...]
            var floatArray = [Float]()
            floatArray.reserveCapacity(points.count * 3)
            
            for point in points {
                floatArray.append(point.x)
                floatArray.append(point.y)
                floatArray.append(point.z)
            }
            
            // Convert to NSData
            let pointData = NSData(bytes: floatArray, length: floatArray.count * MemoryLayout<Float>.size)
            
            // Set the attribute values using our simplified method
            if !pointCloud.setFloatAttributeData(positionAttId, data: pointData as Data) {
                print("Failed to set point data")
                return
            }
            
            // Create an encoder
            let encoder = DracoEncoder()
            
            // Set encoding options for good compression but reasonable quality
            encoder.setSpeedOptions(5, decodingSpeed: 7) // Medium encoding speed, fast decoding
            encoder.setAttributeQuantization(0, bits: 14) // Quantize positions with 14 bits
            
            // Encode the point cloud
            if let encodedData = encoder.encode(pointCloud) {
                // Generate unique filename
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                let timestamp = dateFormatter.string(from: Date())
                let fileName = "pointCloud_\(timestamp).drc"
                let fileURL = documentsDirectory.appendingPathComponent(fileName)
                
                // Save to file
                do {
                    try encodedData.write(to: fileURL)
                    print("Draco encoded point cloud saved to \(fileURL)")
                } catch {
                    print("Error saving Draco encoded point cloud: \(error)")
                }
            } else {
                print("Failed to encode point cloud with Draco")
            }
        }
    }
    
    // Data structure to store frames for PLY video recording
    class PLYVideoBuffer {
        var frames: [(timestamp: Date, points: [SIMD3<Float>])] = []
        var isRecording = false
        var recordingStartTime: Date?
        var timer: Timer?
        
        func startRecording() {
            isRecording = true
            frames = []
            recordingStartTime = Date()
            // Set up timer to capture frames at regular intervals
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.requestFrame()
            }
        }
        
        func stopRecording() {
            isRecording = false
            timer?.invalidate()
            timer = nil
        }
        
        func addFrame(points: [SIMD3<Float>]) {
            if isRecording {
                frames.append((timestamp: Date(), points: points))
            }
        }
        
        func requestFrame() {
            // This function will be called by the timer
            // The actual frame addition will be handled by addFrame when a new point cloud is available
            NotificationCenter.default.post(name: .captureVideoFrame, object: nil)
        }
    }
    
    // Singleton video buffer to be accessed throughout the app
    static var plyVideoBuffer = PLYVideoBuffer()
    
    // Start PLY video recording
    func startPLYVideoRecording() {
        VideoRecordingView.plyVideoBuffer.startRecording()
    }
    
    // Stop PLY video recording and save the result
    func stopPLYVideoRecording() {
        VideoRecordingView.plyVideoBuffer.stopRecording()
        savePLYVideo(frames: VideoRecordingView.plyVideoBuffer.frames)
    }
    
    // Add the current frame to the video buffer
    func capturePLYVideoFrame(points: [SIMD3<Float>]) {
        VideoRecordingView.plyVideoBuffer.addFrame(points: points)
    }
    
    // Save a collection of frames as a PLY video archive
    private func savePLYVideo(frames: [(timestamp: Date, points: [SIMD3<Float>])]) {
        guard !frames.isEmpty else { 
            print("No frames to save")
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            let fileManager = FileManager.default
            guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("Could not access documents directory")
                return
            }
            
            // Create a directory for Draco-encoded frames
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
            let timestamp = dateFormatter.string(from: Date())
            let drcDirName = "plyVideo_\(timestamp).drc.bundle"
            let drcDirURL = documentsDirectory.appendingPathComponent(drcDirName)
            
            do {
                // Create directory
                try fileManager.createDirectory(at: drcDirURL, withIntermediateDirectories: true, attributes: nil)
                
                // Create metadata file
                let metadata: [String: Any] = [
                    "frameCount": frames.count,
                    "recordingDate": timestamp,
                    "frameRate": 1.0 // 1 frame per second
                ]
                
                let metadataData = try JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted)
                
                // Save metadata
                let drcMetadataURL = drcDirURL.appendingPathComponent("metadata.json")
                try metadataData.write(to: drcMetadataURL)
                
                // Save each frame in Draco format only
                for (index, frame) in frames.enumerated() {
                    // Save as Draco
                    let drcFrameFileName = String(format: "frame_%04d.drc", index)
                    let drcFrameFileURL = drcDirURL.appendingPathComponent(drcFrameFileName)
                    
                    // Create a Draco point cloud object
                    let pointCloud = DracoPointCloud()
                    
                    // Set the number of points
                    pointCloud.setNumPoints(frame.points.count)
                    
                    // Add a position attribute (GeometryAttribute::POSITION = 0, DataType::DT_FLOAT32 = 9)
                    let positionAttId = pointCloud.addAttribute(withType: 0, dataType: 9, numComponents: 3, normalized: false)
                    
                    // Convert points to flat array
                    var floatArray = [Float]()
                    floatArray.reserveCapacity(frame.points.count * 3)
                    
                    for point in frame.points {
                        floatArray.append(point.x)
                        floatArray.append(point.y)
                        floatArray.append(point.z)
                    }
                    
                    // Convert to Data
                    let pointData = NSData(bytes: floatArray, length: floatArray.count * MemoryLayout<Float>.size)
                    
                    // Set the attribute values
                    if !pointCloud.setFloatAttributeData(positionAttId, data: pointData as Data) {
                        print("Failed to set point data for frame \(index)")
                        continue
                    }
                    
                    // Create an encoder
                    let encoder = DracoEncoder()
                    
                    // Set encoding options
                    encoder.setSpeedOptions(5, decodingSpeed: 7) // Medium encoding speed, fast decoding
                    encoder.setAttributeQuantization(0, bits: 14) // Quantize positions with 14 bits
                    
                    // Encode the point cloud
                    if let encodedData = encoder.encode(pointCloud) {
                        // Save to file
                        try encodedData.write(to: drcFrameFileURL)
                    } else {
                        print("Failed to encode frame \(index) with Draco")
                    }
                }
                
                print("Draco-encoded PLY video saved to \(drcDirURL)")
                
                // Show a notification to the user
                DispatchQueue.main.async {
                    let notification = UINotificationFeedbackGenerator()
                    notification.notificationOccurred(.success)
                    
                    // Create an alert to show the path
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootViewController = windowScene.windows.first?.rootViewController {
                        let alert = UIAlertController(
                            title: "PLY Video Saved",
                            message: "The Draco-encoded PLY video has been saved to:\n\(drcDirName)",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        rootViewController.present(alert, animated: true)
                    }
                }
                
            } catch {
                print("Error saving PLY video: \(error)")
                
                DispatchQueue.main.async {
                    let notification = UINotificationFeedbackGenerator()
                    notification.notificationOccurred(.error)
                }
            }
        }
    }
    
    // Load a Draco encoded point cloud file and convert it to an array of SIMD3<Float> points
    func loadDracoPointCloudFromFile(url: URL) -> [SIMD3<Float>]? {
        do {
            // Read the file data
            let dracoData = try Data(contentsOf: url)
            
            // Create decoder
            let decoder = DracoDecoder()
            
            // Check if this is a valid point cloud
            let geometryType = DracoDecoder.getEncodedGeometryType(dracoData)
            guard geometryType == .pointCloud else {
                print("File does not contain a valid Draco point cloud")
                return nil
            }
            
            // Decode the point cloud
            guard let pointCloud = decoder.decodePointCloud(from: dracoData) else {
                print("Failed to decode Draco point cloud")
                return nil
            }
            
            // Get the number of points - ensure we're calling it as a function
            let numPoints = pointCloud.numPoints()
            guard numPoints > 0 else {
                print("Point cloud contains no points")
                return nil
            }
            
            // Get the bounding box to verify we have data - ensure we're calling it as a function
            let boundingBox = pointCloud.computeBoundingBox()
            print("Point cloud bounding box: \(boundingBox)")
            
            // Get the position data from the point cloud
            guard let positionData = pointCloud.getPositionData() else {
                print("Failed to extract position data from point cloud")
                return nil
            }
            
            // Convert the raw float data to an array of SIMD3<Float>
            let floatValues = positionData.withUnsafeBytes { rawBuffer -> [Float] in
                guard let floatBuffer = rawBuffer.baseAddress?.assumingMemoryBound(to: Float.self) else {
                    return []
                }
                return Array(UnsafeBufferPointer(start: floatBuffer, count: positionData.count / MemoryLayout<Float>.size))
            }
            
            // Create SIMD3<Float> points from the float array
            var points: [SIMD3<Float>] = []
            points.reserveCapacity(numPoints)
            
            for i in stride(from: 0, to: floatValues.count, by: 3) {
                if i + 2 < floatValues.count {
                    let point = SIMD3<Float>(floatValues[i], floatValues[i+1], floatValues[i+2])
                    points.append(point)
                }
            }
            
            print("Successfully loaded \(points.count) points from Draco file")
            return points
        } catch {
            print("Error loading Draco file: \(error)")
            return nil
        }
    }
    
    // Load a Draco encoded point cloud from a specified file path
    func loadDracoPointCloud(named fileName: String) -> [SIMD3<Float>]? {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Could not access documents directory")
            return nil
        }
        
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        return loadDracoPointCloudFromFile(url: fileURL)
    }
    
    // Load a Draco-encoded PLY video bundle
    func loadDracoPLYVideoBundle(from bundleURL: URL, completion: @escaping ([[SIMD3<Float>]]?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                print("Loading Draco PLY video from: \(bundleURL.path)")
                
                // Check if the directory exists and is a valid bundle
                let fileManager = FileManager.default
                var isDirectory: ObjCBool = false
                if !fileManager.fileExists(atPath: bundleURL.path, isDirectory: &isDirectory) || !isDirectory.boolValue {
                    print("The specified path is not a valid directory")
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                    return
                }
                
                // Look for metadata file
                let metadataURL = bundleURL.appendingPathComponent("metadata.json")
                let metadataExists = fileManager.fileExists(atPath: metadataURL.path)
                
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
                }
                
                // Find DRC files in the bundle
                let contents = try fileManager.contentsOfDirectory(at: bundleURL, includingPropertiesForKeys: nil, options: [])
                let drcFiles = contents.filter { $0.pathExtension.lowercased() == "drc" }
                    .sorted { $0.lastPathComponent < $1.lastPathComponent }
                
                print("Found \(drcFiles.count) DRC files")
                
                if drcFiles.isEmpty {
                    print("No DRC files found in the directory")
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                    return
                }
                
                // If no metadata, use the count of DRC files
                if frameCount == 0 {
                    frameCount = drcFiles.count
                }
                
                // Load all frames
                var frames: [[SIMD3<Float>]] = []
                for (index, drcFile) in drcFiles.enumerated() {
                    print("Loading DRC file \(index+1)/\(drcFiles.count): \(drcFile.lastPathComponent)")
                    if let points = self.loadDracoPointCloudFromFile(url: drcFile) {
                        print("  - Loaded \(points.count) points")
                        frames.append(points)
                    } else {
                        print("  - Failed to load frame")
                    }
                }
                
                if frames.isEmpty {
                    print("Failed to load any frames from the DRC bundle")
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                    return
                }
                
                // Return the frames
                print("Successfully loaded \(frames.count) Draco-encoded frames")
                DispatchQueue.main.async {
                    completion(frames)
                }
            } catch {
                print("Error loading Draco PLY video: \(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
}

// Define notification names
extension Notification.Name {
    static let captureVideoFrame = Notification.Name("captureVideoFrame")
}
