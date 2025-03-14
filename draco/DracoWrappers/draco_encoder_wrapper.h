//
//  draco_encoder_wrapper.h
//  spacetime-mic
//
//  Created by David Girardo on 3/14/25.
//

#ifndef draco_encoder_wrapper_h
#define draco_encoder_wrapper_h

#import <Foundation/Foundation.h>
#import "draco_point_cloud_wrapper.h"

NS_ASSUME_NONNULL_BEGIN

@interface DracoEncoder : NSObject

// Create a new encoder
- (instancetype)init;

// Encode a point cloud to a buffer
// Returns NSData containing the encoded point cloud, or nil on failure
- (nullable NSData *)encodePointCloud:(DracoPointCloud *)pointCloud;

// Set the speed options for encoding and decoding
// encoding_speed: 0 = slowest/best compression, 10 = fastest/worst compression
// decoding_speed: 0 = slowest/best compression, 10 = fastest/worst compression
- (void)setSpeedOptions:(int)encodingSpeed decodingSpeed:(int)decodingSpeed;

// Set quantization (compression) for a specific attribute type
// type: The attribute type (position, normal, etc.)
// quantizationBits: Number of bits used for quantization (higher = better quality but larger size)
- (void)setAttributeQuantization:(NSInteger)type bits:(int)quantizationBits;

// Set the encoding method to be used
// method: The encoding method (POINT_CLOUD_SEQUENTIAL_ENCODING or POINT_CLOUD_KD_TREE_ENCODING)
- (void)setEncodingMethod:(int)method;

@end

NS_ASSUME_NONNULL_END

#endif /* draco_encoder_wrapper_h */ 