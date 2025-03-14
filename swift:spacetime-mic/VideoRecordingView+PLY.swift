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
        
        // Add a position attribute (GeometryAttribute::POSITION = 0, DataType::FLOAT32 = 5)
        // 3 components (x,y,z), not normalized
        let positionAttId = pointCloud.addAttributeWithType(0, dataType: 5, numComponents: 3, normalized: false)
        
        // Here we would normally populate the attribute with point data
        // However, our current wrapper doesn't expose a direct way to set attribute values
        // We would need to enhance the wrapper to support this
        
        // Create an encoder
        let encoder = DracoEncoder()
        
        // Set encoding options for good compression but reasonable quality
        encoder.setSpeedOptions(5, decodingSpeed: 7) // Medium encoding speed, fast decoding
        encoder.setAttributeQuantization(0, bits: 14) // Quantize positions with 14 bits
        
        // Encode the point cloud
        if let encodedData = encoder.encodePointCloud(pointCloud) {
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