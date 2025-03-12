//
//  VideoRecordingView+PLY.swift
//  spacetime-mic
//
//  Created by David Girardo on 3/12/25.
//

import Foundation

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
}
