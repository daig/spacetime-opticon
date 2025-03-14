//
//  draco_encoder_wrapper.mm
//  spacetime-mic
//
//  Created by David Girardo on 3/14/25.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h> // For Objective-C runtime functions
#import "draco_encoder_wrapper.h"
#import "draco_point_cloud_wrapper.h"

// Include the Draco headers
#include "../compression/encode.h"
#include "../point_cloud/point_cloud.h"
#include "../attributes/geometry_attribute.h"
#include "../core/encoder_buffer.h"
#include "../core/status.h"

// Private class extension to hold the C++ object
@interface DracoEncoder () {
    draco::Encoder* _encoder;
}
@end

@implementation DracoEncoder

- (instancetype)init {
    self = [super init];
    if (self) {
        _encoder = new draco::Encoder();
    }
    return self;
}

- (void)dealloc {
    if (_encoder) {
        delete _encoder;
        _encoder = nullptr;
    }
}

- (nullable NSData *)encodePointCloud:(DracoPointCloud *)pointCloud {
    if (!_encoder || !pointCloud) {
        return nil;
    }
    
    // Access the internal C++ point cloud object using Objective-C runtime
    Ivar ivar = class_getInstanceVariable([DracoPointCloud class], "_pointCloud");
    if (!ivar) {
        return nil;
    }
    
    // Get the pointer to the C++ object
    draco::PointCloud* dracoPointCloud = (__bridge draco::PointCloud*)object_getIvar(pointCloud, ivar);
    if (!dracoPointCloud) {
        return nil;
    }
    
    // Create a buffer to store the encoded data
    draco::EncoderBuffer buffer;
    
    // Encode the point cloud
    const draco::Status status = _encoder->EncodePointCloudToBuffer(*dracoPointCloud, &buffer);
    
    if (!status.ok()) {
        // Encoding failed
        return nil;
    }
    
    // Create NSData from the buffer
    return [NSData dataWithBytes:buffer.data() length:buffer.size()];
}

- (void)setSpeedOptions:(int)encodingSpeed decodingSpeed:(int)decodingSpeed {
    if (_encoder) {
        _encoder->SetSpeedOptions(encodingSpeed, decodingSpeed);
    }
}

- (void)setAttributeQuantization:(NSInteger)type bits:(int)quantizationBits {
    if (_encoder) {
        _encoder->SetAttributeQuantization(
            static_cast<draco::GeometryAttribute::Type>(type), 
            quantizationBits);
    }
}

- (void)setEncodingMethod:(int)method {
    if (_encoder) {
        _encoder->SetEncodingMethod(method);
    }
}

@end 
