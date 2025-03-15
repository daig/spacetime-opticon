//
//  draco_wrapper.m
//  spacetime-mic
//
//  Created by David Girardo on 3/14/25.
//

#import <Foundation/Foundation.h>
#import "draco_point_cloud_wrapper.h"

// Include the Draco headers
#include "../point_cloud/point_cloud.h"
#include "../attributes/geometry_attribute.h"
#include "../attributes/point_attribute.h"
#include "../core/draco_index_type.h"
#include "../core/bounding_box.h"
#include "../core/draco_types.h"

// Private class extension to hold the C++ object
@interface DracoPointCloud () {
    draco::PointCloud* _pointCloud;
}
@end

@implementation DracoPointCloud

- (instancetype)init {
    self = [super init];
    if (self) {
        _pointCloud = new draco::PointCloud();
    }
    return self;
}

- (void)dealloc {
    if (_pointCloud) {
        delete _pointCloud;
        _pointCloud = nullptr;
    }
}

- (NSInteger)numPoints {
    if (_pointCloud) {
        return _pointCloud->num_points();
    }
    return 0;
}

- (void)setNumPoints:(NSInteger)numPoints {
    if (_pointCloud) {
        _pointCloud->set_num_points(static_cast<uint32_t>(numPoints));
    }
}

- (NSInteger)numAttributes {
    if (_pointCloud) {
        return _pointCloud->num_attributes();
    }
    return 0;
}

- (NSInteger)addAttributeWithType:(NSInteger)type
                         dataType:(NSInteger)dataType
                    numComponents:(NSInteger)numComponents
                       normalized:(BOOL)normalized {
    if (!_pointCloud) {
        return -1;
    }
    
    draco::GeometryAttribute attribute;
    attribute.Init(static_cast<draco::GeometryAttribute::Type>(type),
                  nullptr,
                  static_cast<int>(numComponents),
                  static_cast<draco::DataType>(dataType),
                  normalized,
                  0, 0);
    
    // Create attribute with identity mapping and add to point cloud
    return _pointCloud->AddAttribute(attribute, true, 0);
}

- (NSArray<NSNumber *> *)computeBoundingBox {
    if (!_pointCloud) {
        return @[];
    }
    
    draco::BoundingBox bbox = _pointCloud->ComputeBoundingBox();
    NSMutableArray<NSNumber *> *result = [NSMutableArray arrayWithCapacity:6];
    
    // Add min point coordinates
    [result addObject:@(bbox.GetMinPoint()[0])];
    [result addObject:@(bbox.GetMinPoint()[1])];
    [result addObject:@(bbox.GetMinPoint()[2])];
    
    // Add max point coordinates
    [result addObject:@(bbox.GetMaxPoint()[0])];
    [result addObject:@(bbox.GetMaxPoint()[1])];
    [result addObject:@(bbox.GetMaxPoint()[2])];
    
    return result;
}

- (BOOL)setFloatAttributeData:(NSInteger)attributeId data:(NSData *)floatData {
    if (!_pointCloud || attributeId < 0 || attributeId >= _pointCloud->num_attributes() || !floatData) {
        NSLog(@"Error: Invalid inputs to setFloatAttributeData");
        return NO;
    }
    
    // Get the attribute - ensure we cast it as draco::GeometryAttribute to match API
    draco::GeometryAttribute* attribute = static_cast<draco::GeometryAttribute*>(_pointCloud->attribute(static_cast<int32_t>(attributeId)));
    if (!attribute) {
        NSLog(@"Error: Could not get attribute %ld", (long)attributeId);
        return NO;
    }
    
    // Verify we're working with float data
    if (attribute->data_type() != draco::DT_FLOAT32) {
        NSLog(@"Error: Attribute is not of float type");
        return NO;
    }
    
    const size_t numComponents = attribute->num_components();
    const size_t numPoints = _pointCloud->num_points();
    const size_t expectedDataSize = numPoints * numComponents * sizeof(float);
    
    if (floatData.length != expectedDataSize) {
        NSLog(@"Error: Data size mismatch: expected %zu bytes, got %zu bytes", expectedDataSize, floatData.length);
        return NO;
    }
    
    // Get raw pointer to the float data
    const float *floatValues = static_cast<const float *>(floatData.bytes);
    
    NSLog(@"Setting attribute data for %zu points with %zu components each", numPoints, numComponents);
    
    // For each point, we'll use the appropriate API to set the attribute value
    bool success = true;
    
    // Set the attribute values point by point
    for (uint32_t pointId = 0; pointId < numPoints; pointId++) {
        const float *pointValues = floatValues + (pointId * numComponents);
        
        // Method 1: Use direct data buffer access
        try {
            // Get the attribute value index using the PointAttribute's methods
            uint32_t valueIndex = pointId;  // Identity mapping
            
            // Cast as PointAttribute for access to GetAddress method
            draco::PointAttribute* pointAttr = static_cast<draco::PointAttribute*>(attribute);
            uint8_t* dstAddress = pointAttr->GetAddress(draco::AttributeValueIndex(valueIndex));
            
            // If GetAddress fails, try an alternate approach
            if (!dstAddress && pointId == 0) {
                NSLog(@"GetAddress returned null, trying alternate approach");
                
                // Try to get the buffer directly and use stride-based indexing
                if (pointAttr->buffer() && pointAttr->buffer()->data()) {
                    NSLog(@"Using direct buffer approach");
                    
                    uint8_t* bufferStart = const_cast<uint8_t*>(pointAttr->buffer()->data());
                    size_t stride = pointAttr->byte_stride();
                    
                    // Copy point data to the appropriate buffer location
                    for (uint32_t i = 0; i < numPoints; i++) {
                        const float *srcPoint = floatValues + (i * numComponents);
                        float *dstPoint = reinterpret_cast<float*>(bufferStart + i * stride);
                        
                        // Copy each component
                        for (size_t c = 0; c < numComponents; c++) {
                            dstPoint[c] = srcPoint[c];
                        }
                        
                        // Log first and last points
                        if (i == 0 || i == numPoints - 1) {
                            NSLog(@"Set point %u: (%f, %f, %f)", i,
                                  srcPoint[0],
                                  numComponents > 1 ? srcPoint[1] : 0.0f,
                                  numComponents > 2 ? srcPoint[2] : 0.0f);
                        }
                    }
                    
                    // Mark as successful and skip the rest of the loop
                    success = true;
                    break;
                }
            }
            
            if (dstAddress) {
                // Copy the float data directly to the attribute's memory
                memcpy(dstAddress, pointValues, numComponents * sizeof(float));
                
                // Log first and last point for verification
                if (pointId == 0 || pointId == numPoints - 1) {
                    NSLog(@"Set point %u: (%f, %f, %f)", pointId,
                         pointValues[0],
                         numComponents > 1 ? pointValues[1] : 0.0f,
                         numComponents > 2 ? pointValues[2] : 0.0f);
                }
            } else {
                // If we couldn't get an address for the first point, that's a critical error
                if (pointId == 0) {
                    NSLog(@"Error: Could not get attribute data address for point 0");
                    return NO;
                }
                success = false;
            }
        } catch (...) {
            // If the first point fails, log and fail
            if (pointId == 0) {
                NSLog(@"Error: Exception setting data for point 0");
                return NO;
            }
            success = false;
        }
    }
    
    if (success) {
        NSLog(@"Successfully set attribute data for all %zu points", numPoints);
    } else {
        NSLog(@"Warning: Some points may not have been set correctly");
    }
    
    return success;
}

- (nullable NSData *)getPositionData {
    if (!_pointCloud) {
        NSLog(@"Error: No point cloud object exists");
        return nil;
    }
    
    // Find the position attribute by iterating through all attributes
    // Position attribute typically has type POSITION = 0
    int attributeId = -1;
    for (int i = 0; i < _pointCloud->num_attributes(); ++i) {
        // Cast to GeometryAttribute for attribute_type access
        const draco::GeometryAttribute* att = static_cast<const draco::GeometryAttribute*>(_pointCloud->attribute(i));
        if (att && att->attribute_type() == 0) { // 0 = POSITION in Draco
            attributeId = i;
            break;
        }
    }
    
    if (attributeId == -1) {
        NSLog(@"Error: No position attribute found in point cloud");
        return nil;
    }
    
    // Get the position attribute - cast to GeometryAttribute for API compatibility
    const draco::GeometryAttribute *geomAttribute = static_cast<const draco::GeometryAttribute*>(_pointCloud->attribute(attributeId));
    if (!geomAttribute) {
        NSLog(@"Error: Failed to get position attribute");
        return nil;
    }
    
    // Also get as PointAttribute for GetAddress access
    const draco::PointAttribute *positionAttribute = static_cast<const draco::PointAttribute*>(geomAttribute);
    
    // Check if it's a float attribute
    if (geomAttribute->data_type() != draco::DT_FLOAT32) {
        NSLog(@"Error: Position attribute is not of float type");
        return nil;
    }
    
    const size_t numComponents = geomAttribute->num_components();
    const size_t numPoints = _pointCloud->num_points();
    const size_t dataSize = numPoints * numComponents * sizeof(float);
    
    // Log key information for debugging
    NSLog(@"Position attribute info: %d points, %zu components", 
          _pointCloud->num_points(), numComponents);
          
    // Check the attribute's byte stride (should be numComponents * sizeof(float))
    size_t byteStride = geomAttribute->byte_stride();
    NSLog(@"Attribute byte stride: %zu (expected %zu)", 
          byteStride, numComponents * sizeof(float));
    
    // Create a buffer to hold the point data
    float *pointBuffer = (float *)malloc(dataSize);
    if (!pointBuffer) {
        NSLog(@"Error: Failed to allocate memory for point data (%zu bytes)", dataSize);
        return nil;
    }
    
    // Initialize buffer with zeros
    memset(pointBuffer, 0, dataSize);
    
    // Use direct memory access to get the real point data
    bool success = false;
    
    try {
        // Get a pointer to the start of the attribute data
        // For PointAttribute, we can usually access the data directly
        const uint8_t* srcBuffer = positionAttribute->GetAddress(draco::AttributeValueIndex(0));
        
        // If GetAddress returns null, try a different approach
        if (!srcBuffer) {
            NSLog(@"GetAddress returned null, trying alternate approach");
            srcBuffer = positionAttribute->buffer()->data();
        }
        
        if (srcBuffer && byteStride > 0) {
            NSLog(@"Extracting real point data using direct buffer access");
            
            // Copy the data with the correct stride
            for (uint32_t pointId = 0; pointId < numPoints; pointId++) {
                float* currentPoint = pointBuffer + (pointId * numComponents);
                
                // Calculate attribute value index
                uint32_t valueIndex = pointId;  // Identity mapping
                size_t offset = valueIndex * byteStride;
                const float* srcPoint = reinterpret_cast<const float*>(srcBuffer + offset);
                
                // Copy each component
                for (size_t c = 0; c < numComponents; c++) {
                    currentPoint[c] = srcPoint[c];
                }
                
                // Log first and last point for verification
                if (pointId == 0 || pointId == numPoints - 1) {
                    NSLog(@"Point %u: (%f, %f, %f)", pointId,
                         currentPoint[0],
                         numComponents > 1 ? currentPoint[1] : 0,
                         numComponents > 2 ? currentPoint[2] : 0);
                }
            }
            
            success = true;
        } else {
            NSLog(@"Error: Failed to get attribute buffer address or stride is invalid");
        }
    } catch (...) {
        NSLog(@"Exception while accessing attribute data buffer");
    }
    
    // If we failed to extract the data, we need to fail - NOT create fake data
    if (!success) {
        NSLog(@"Error: Failed to extract real point data from the point cloud");
        free(pointBuffer);
        return nil;
    }
    
    NSLog(@"Successfully extracted %zu points with %zu components each", 
          numPoints, numComponents);
    
    // Create NSData from our buffer, which will take ownership and free memory when released
    return [NSData dataWithBytesNoCopy:pointBuffer 
                                length:dataSize 
                          freeWhenDone:YES];
}

@end
