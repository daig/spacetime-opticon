//
//  draco_decoder_wrapper.mm
//  spacetime-mic
//
//  Created by David Girardo on 3/14/25.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h> // For Objective-C runtime functions
#import "draco_decoder_wrapper.h"
#import "draco_point_cloud_wrapper.h"

// Include the Draco headers
#include "../compression/decode.h"
#include "../point_cloud/point_cloud.h"
#include "../core/decoder_buffer.h"
#include "../core/status_or.h"

// Private class extension to hold the C++ object
@interface DracoDecoder () {
    draco::Decoder* _decoder;
}
@end

@implementation DracoDecoder

+ (DracoGeometryType)getEncodedGeometryType:(NSData *)data {
    if (!data || data.length == 0) {
        return DracoGeometryTypeInvalid;
    }
    
    // Create a decoder buffer from the input data
    draco::DecoderBuffer buffer;
    buffer.Init(static_cast<const char*>(data.bytes), data.length);
    
    // Get the encoded geometry type
    auto statusOr = draco::Decoder::GetEncodedGeometryType(&buffer);
    if (!statusOr.ok()) {
        return DracoGeometryTypeInvalid;
    }
    
    draco::EncodedGeometryType geometryType = statusOr.value();
    switch (geometryType) {
        case draco::POINT_CLOUD:
            return DracoGeometryTypePointCloud;
        case draco::TRIANGULAR_MESH:
            return DracoGeometryTypeMesh;
        default:
            return DracoGeometryTypeInvalid;
    }
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _decoder = new draco::Decoder();
    }
    return self;
}

- (void)dealloc {
    if (_decoder) {
        delete _decoder;
        _decoder = nullptr;
    }
}

- (nullable DracoPointCloud *)decodePointCloudFromData:(NSData *)data {
    if (!_decoder || !data || data.length == 0) {
        return nil;
    }
    
    // Create a decoder buffer from the input data
    draco::DecoderBuffer buffer;
    buffer.Init(static_cast<const char*>(data.bytes), data.length);
    
    // Create a new DracoPointCloud wrapper first
    DracoPointCloud *pointCloud = [[DracoPointCloud alloc] init];
    if (!pointCloud) {
        return nil;
    }
    
    // Access the internal C++ point cloud object using Objective-C runtime
    Ivar ivar = class_getInstanceVariable([DracoPointCloud class], "_pointCloud");
    if (!ivar) {
        return nil;
    }
    
    // Delete the default point cloud that was created in the init method
    draco::PointCloud* existingPointCloud = (__bridge draco::PointCloud*)object_getIvar(pointCloud, ivar);
    if (existingPointCloud) {
        delete existingPointCloud;
    }
    
    // Decode the point cloud - create a new raw pointer to hold the result
    std::unique_ptr<draco::PointCloud> tempPointCloud;
    
    // Try to decode the buffer
    auto status = _decoder->DecodeBufferToGeometry(&buffer, tempPointCloud.get());
    
    // Check if decoding was successful
    if (!status.ok() || !tempPointCloud) {
        NSLog(@"Failed to decode Draco point cloud");
        return nil;
    }
    
    // Get raw pointer and release ownership from unique_ptr
    draco::PointCloud* decodedPointCloud = tempPointCloud.release();
    
    // Set the decoded point cloud in our wrapper
    object_setIvar(pointCloud, ivar, (__bridge id)decodedPointCloud);
    
    return pointCloud;
}

- (void)setSkipAttributeTransform:(NSInteger)attributeType {
    if (_decoder) {
        _decoder->SetSkipAttributeTransform(static_cast<draco::GeometryAttribute::Type>(attributeType));
    }
}

@end 