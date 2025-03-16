import Foundation

// Service class to handle all Draco-related operations
class DracoService {
    // MARK: - Singleton
    static let shared = DracoService()
    private init() {}
    
    // MARK: - Point Cloud Loading
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
            
            // Get the number of points
            let numPoints = pointCloud.numPoints()
            guard numPoints > 0 else {
                print("Point cloud contains no points")
                return nil
            }
            
            // Get the bounding box to verify we have data
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
    
    // MARK: - PLY Video Bundle Loading
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
    
    // MARK: - Point Cloud Encoding
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
            
            // Apply dynamic compression settings based on point count
            // For dense point clouds, we can use more aggressive compression
            let pointCount = points.count
            
            if pointCount < 5000 {
                // For smaller point clouds, use lighter compression to preserve detail
                encoder.setSpeedOptions(5, decodingSpeed: 9)
                encoder.setAttributeQuantization(0, bits: 12)
            } else if pointCount < 20000 {
                // Medium point clouds get more compression
                encoder.setSpeedOptions(4, decodingSpeed: 8)
                encoder.setAttributeQuantization(0, bits: 11)
            } else {
                // Large point clouds get the most aggressive compression
                encoder.setSpeedOptions(3, decodingSpeed: 7)
                encoder.setAttributeQuantization(0, bits: 10)
            }
            
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
} 