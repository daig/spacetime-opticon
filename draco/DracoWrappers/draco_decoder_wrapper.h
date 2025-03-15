//
//  draco_decoder_wrapper.h
//  spacetime-mic
//
//  Created by David Girardo on 3/14/25.
//

#import <Foundation/Foundation.h>

@class DracoPointCloud;

// Enum to represent encoded geometry types
typedef NS_ENUM(NSInteger, DracoGeometryType) {
    DracoGeometryTypeInvalid = -1,
    DracoGeometryTypePointCloud = 0,
    DracoGeometryTypeMesh = 1
};

// Wrapper for the Draco Decoder C++ class
@interface DracoDecoder : NSObject

/**
 * Determines the type of geometry encoded in the data.
 * @param data The encoded Draco data
 * @return The geometry type (point cloud, mesh, or invalid)
 */
+ (DracoGeometryType)getEncodedGeometryType:(NSData *)data;

/**
 * Decodes a point cloud from the provided data.
 * @param data The encoded Draco data
 * @return A DracoPointCloud object if successful, or nil if decoding failed
 */
- (nullable DracoPointCloud *)decodePointCloudFromData:(NSData *)data;

/**
 * Swift-friendly method to decode a point cloud from the provided data.
 * @param from The encoded Draco data
 * @return A DracoPointCloud object if successful, or nil if decoding failed
 */
- (nullable DracoPointCloud *)decodePointCloud:(NSData *)from;

/**
 * Sets whether to skip attribute transform for the specified attribute type.
 * When set, the decoder will not apply transforms like dequantization.
 * @param attributeType The attribute type to skip transform for
 */
- (void)setSkipAttributeTransform:(NSInteger)attributeType;

@end 