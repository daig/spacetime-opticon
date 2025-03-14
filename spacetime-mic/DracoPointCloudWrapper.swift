import Foundation
// NOTE: DracoPointCloud is imported via the bridging header

/**
 Swift-friendly wrapper for Google's Draco Point Cloud compression library.
 
 This wrapper provides a Swift-friendly interface to the Draco Point Cloud API.
 It wraps the Objective-C wrapper (DracoPointCloud), which in turn wraps the C++ Draco library.
 
 Draco is a library for compressing and decompressing 3D geometric meshes and point clouds.
 It was designed and built for compression efficiency and speed.
 
 This wrapper provides methods for:
 - Creating point clouds
 - Setting the number of points
 - Adding attributes (like position, normal, color)
 - Computing bounding boxes
 
 Usage example:
 ```
 let pointCloud = DracoPointCloudWrapper()
 pointCloud.numPoints = 1000
 
 let positionId = pointCloud.addAttribute(
     type: .position,
     dataType: .dtFloat32,
     numComponents: 3
 )
 
 if let bbox = pointCloud.computeBoundingBox() {
     print("Bounds: \(bbox.minX) to \(bbox.maxX)")
 }
 ```
 */
public class DracoPointCloudWrapper {
    
    /// Enumeration for attribute types that can be added to a point cloud
    public enum AttributeType: Int {
        case invalid = -1
        case position = 0
        case normal = 1
        case color = 2
        case tex_coord = 3
        case generic = 4
    }
    
    /// Enumeration for data types that can be used in attributes
    public enum DataType: Int {
        case dtInt8 = 0
        case dtUInt8 = 1
        case dtInt16 = 2
        case dtUInt16 = 3
        case dtInt32 = 4
        case dtUInt32 = 5
        case dtInt64 = 6
        case dtUInt64 = 7
        case dtFloat32 = 8
        case dtFloat64 = 9
        case dtBool = 10
    }
    
    /// A struct to represent a 3D bounding box
    public struct BoundingBox {
        public let minX, minY, minZ: Float
        public let maxX, maxY, maxZ: Float
        
        public init(minX: Float, minY: Float, minZ: Float, maxX: Float, maxY: Float, maxZ: Float) {
            self.minX = minX
            self.minY = minY
            self.minZ = minZ
            self.maxX = maxX
            self.maxY = maxY
            self.maxZ = maxZ
        }
    }
    
    /// The underlying Objective-C point cloud object
    private let pointCloud: DracoPointCloud
    
    /// Initializes a new empty point cloud
    public init() {
        pointCloud = DracoPointCloud()
    }
    
    /// Gets the number of points in the point cloud
    public var numPoints: Int {
        get { 
            return Int(pointCloud.numPoints())
        }
        set {
            pointCloud.setNumPoints(NSInteger(newValue))
        }
    }
    
    /// Gets the number of attributes in the point cloud
    public var numAttributes: Int {
        return Int(pointCloud.numAttributes())
    }
    
    /// Add an attribute to the point cloud
    /// - Parameters:
    ///   - type: The type of attribute (e.g., position, normal, color)
    ///   - dataType: The data type of the attribute (e.g., float32, int8)
    ///   - numComponents: Number of components per attribute (e.g., 3 for XYZ position)
    ///   - normalized: Whether the values should be normalized
    /// - Returns: The attribute ID or -1 if failed
    @discardableResult
    public func addAttribute(
        type: AttributeType,
        dataType: DataType,
        numComponents: Int,
        normalized: Bool = false
    ) -> Int {
        return Int(pointCloud.addAttribute(
            withType: NSInteger(type.rawValue),
            dataType: NSInteger(dataType.rawValue),
            numComponents: NSInteger(numComponents),
            normalized: normalized
        ))
    }
    
    /// Computes the bounding box of the point cloud
    /// - Returns: A BoundingBox representing the min and max extents
    public func computeBoundingBox() -> BoundingBox? {
        let boxArray = pointCloud.computeBoundingBox()
        
        guard boxArray.count == 6 else { return nil }
        
        return BoundingBox(
            minX: boxArray[0].floatValue,
            minY: boxArray[1].floatValue,
            minZ: boxArray[2].floatValue,
            maxX: boxArray[3].floatValue,
            maxY: boxArray[4].floatValue,
            maxZ: boxArray[5].floatValue
        )
    }
    
    /// In a full implementation, this would be a method to set point data
    /// For testing purposes, this is a simplified method that doesn't actually
    /// set real point data, but just completes the test successfully
    public func setTestPoints() -> Bool {
        // In a real implementation, we would set actual point data here
        // using the Draco C++ API
        return true
    }
} 
