import Foundation
import SwiftUI

/// A simple view to test the Draco point cloud wrapper
struct DracoPointCloudTestView: View {
    @State private var resultText = "Run the test to see results"
    @State private var numPoints = 1000
    @State private var isLoading = false
    @State private var showMoreInfo = false
    
    func testDracoPointCloud() {
        isLoading = true
        resultText = "Testing Draco Point Cloud..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            var results = [String]()
            
            // First test the Objective-C API directly
            results.append("--- Testing Objective-C API ---")
            
            // Create a new point cloud directly using the Objective-C API
            let pointCloud = DracoPointCloud()
            results.append("✓ Created DracoPointCloud object")
            
            // Set the number of points
            pointCloud.setNumPoints(NSInteger(numPoints))
            results.append("✓ Set num points to \(pointCloud.numPoints())")
            
            // Add a position attribute (3 components, float32)
            let positionAttrId = pointCloud.addAttribute(withType: 0, // Position type
                                                        dataType: 8, // Float32
                                                        numComponents: 3, // XYZ
                                                        normalized: false)
            results.append("✓ Added position attribute with ID: \(positionAttrId)")
            
            // Add a normal attribute (3 components, float32)
            let normalAttrId = pointCloud.addAttribute(withType: 1, // Normal type
                                                      dataType: 8, // Float32
                                                      numComponents: 3, // XYZ
                                                      normalized: true)
            results.append("✓ Added normal attribute with ID: \(normalAttrId)")
            
            // Add a color attribute (3 components, uint8)
            let colorAttrId = pointCloud.addAttribute(withType: 2, // Color type
                                                     dataType: 1, // UInt8
                                                     numComponents: 3, // RGB
                                                     normalized: true)
            results.append("✓ Added color attribute with ID: \(colorAttrId)")
            
            // Report the total number of attributes
            results.append("✓ Total attributes: \(pointCloud.numAttributes())")
            
            // NOTE: We would need to set actual point data to compute a meaningful bounding box
            results.append("ℹ️ Skipping bounding box computation as no point data has been set")
            
            // Now try to use the Swift wrapper
            results.append("\n--- Testing Swift Wrapper ---")
            
            let wrapper = DracoPointCloudWrapper()
            results.append("✓ Created Swift wrapper")
            
            wrapper.numPoints = numPoints
            results.append("✓ Set num points to \(wrapper.numPoints)")
            
            let positionId = wrapper.addAttribute(
                type: .position,
                dataType: .dtFloat32,
                numComponents: 3
            )
            results.append("✓ Added position attribute with ID: \(positionId)")
            
            let normalId = wrapper.addAttribute(
                type: .normal,
                dataType: .dtFloat32,
                numComponents: 3,
                normalized: true
            )
            results.append("✓ Added normal attribute with ID: \(normalId)")
            
            let colorId = wrapper.addAttribute(
                type: .color,
                dataType: .dtUInt8,
                numComponents: 3,
                normalized: true
            )
            results.append("✓ Added color attribute with ID: \(colorId)")
            
            results.append("✓ Total attributes: \(wrapper.numAttributes)")
            
            // Use our placeholder method that would set point data in a real implementation
            let setPointsResult = wrapper.setTestPoints()
            if setPointsResult {
                results.append("✓ Set test point data")
            } else {
                results.append("✗ Failed to set test point data")
            }
            
            results.append("ℹ️ Note: A full implementation would populate the point cloud with actual point data")
            results.append("ℹ️ and then compute meaningful bounding boxes and other metrics")
            
            DispatchQueue.main.async {
                resultText = results.joined(separator: "\n")
                isLoading = false
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Draco Point Cloud Test")
                    .font(.largeTitle)
                    .padding(.bottom, 8)
                
                Text("This test verifies that the Draco library integration is working properly by creating a point cloud and adding attributes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Divider()
                
                DisclosureGroup("About This Test", isExpanded: $showMoreInfo) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("This test demonstrates basic integration with Google's Draco point cloud library. It:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text("• Creates a point cloud with the specified number of points")
                        Text("• Adds position, normal, and color attributes")
                        Text("• Demonstrates the Swift wrapper's functionality")
                        
                        Text("Note: This is a basic integration test that doesn't populate actual point data or perform compression. Those features would be added in a full implementation.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    }
                    .padding(.vertical, 8)
                }
                
                Divider()
                
                HStack {
                    Text("Number of points:")
                    Slider(value: Binding(
                        get: { Double(numPoints) },
                        set: { numPoints = Int($0) }
                    ), in: 100...10000, step: 100)
                    Text("\(numPoints)")
                        .frame(width: 60, alignment: .trailing)
                        .monospacedDigit()
                }
                
                Button(action: testDracoPointCloud) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Run Test")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.vertical, 8)
                .disabled(isLoading)
                
                GroupBox("Test Results") {
                    ScrollView {
                        Text(resultText)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(height: 400)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    DracoPointCloudTestView()
} 
