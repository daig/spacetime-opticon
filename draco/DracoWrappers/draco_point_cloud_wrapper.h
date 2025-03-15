//
//  draco_wrapper.h
//  spacetime-mic
//
//  Created by David Girardo on 3/14/25.
//

#ifndef draco_wrapper_h
#define draco_wrapper_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DracoPointCloud : NSObject

// Create a new point cloud
- (instancetype)init;

// Get the number of points in the point cloud
- (NSInteger)numPoints;

// Set the number of points in the point cloud
- (void)setNumPoints:(NSInteger)numPoints;

// Get the number of attributes
- (NSInteger)numAttributes;

// Add an attribute to the point cloud (simplified interface)
- (NSInteger)addAttributeWithType:(NSInteger)type 
                   dataType:(NSInteger)dataType 
                   numComponents:(NSInteger)numComponents 
                   normalized:(BOOL)normalized;

// Get the bounding box as an array of 6 floats [min_x, min_y, min_z, max_x, max_y, max_z]
- (NSArray<NSNumber *> *)computeBoundingBox;

// Set attribute data directly from a flat array of floats
// attributeId: The ID of the attribute to set values for
// floatData: NSData containing raw float values in the format [x1,y1,z1,x2,y2,z2,...]
// Returns YES if successful, NO otherwise
- (BOOL)setFloatAttributeData:(NSInteger)attributeId data:(NSData *)floatData;

// Get the position attribute data as an array of floats
// Returns nil if there is no position attribute or if the data cannot be accessed
// The returned data is organized as [x1,y1,z1,x2,y2,z2,...]
- (nullable NSData *)getPositionData;

@end

NS_ASSUME_NONNULL_END

#endif /* draco_wrapper_h */
