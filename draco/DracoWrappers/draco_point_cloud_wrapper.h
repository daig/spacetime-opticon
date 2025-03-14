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

@end

NS_ASSUME_NONNULL_END

#endif /* draco_wrapper_h */
