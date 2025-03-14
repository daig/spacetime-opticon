//
//  VideoRecordingView+PLY.swift
//  spacetime-mic
//
//  Created by David Girardo on 3/12/25.
//

import Foundation
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
}
