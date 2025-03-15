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
#include "../attributes/geometry_attribute.h" // Include for GeometryAttribute::Type

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
    
    // Since we can't use the enums directly, we'll check some properties of the 
    // buffer to determine the type. Not ideal, but a workaround.
    
    // Try to get the geometry type using the API
    auto statusOr = draco::Decoder::GetEncodedGeometryType(&buffer);
    if (statusOr.ok()) {
        // Map the int value - 0 is point cloud, 1 is mesh in the Draco API
        int geometryType = static_cast<int>(statusOr.value());
        if (geometryType == 0) {
            return DracoGeometryTypePointCloud;
        } else if (geometryType == 1) {
            return DracoGeometryTypeMesh;
        }
    }
    
    return DracoGeometryTypeInvalid;
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
    // Input validation
    if (!_decoder || !data || data.length == 0) {
        NSLog(@"[DracoDecode] Invalid input: decoder=%p, data=%p, length=%lu", 
              _decoder, data, (unsigned long)data.length);
        return nil;
    }
    
    NSLog(@"[DracoDecode] Starting to decode Draco point cloud from data of length %lu bytes", 
          (unsigned long)data.length);
    
    @try {
        // Create a decoder buffer from the input data
        draco::DecoderBuffer buffer;
        buffer.Init(static_cast<const char*>(data.bytes), data.length);
        
        // Check if this is a point cloud
        DracoGeometryType geomType = [DracoDecoder getEncodedGeometryType:data];
        if (geomType != DracoGeometryTypePointCloud) {
            NSLog(@"[DracoDecode] Not a point cloud - geometry type: %ld", (long)geomType);
            return nil;
        }
        
        // Reset the buffer for decoding
        buffer.StartDecodingFrom(0);
        
        NSLog(@"[DracoDecode] Decoding point cloud from buffer");
        
        // Create a point cloud manually and decode into it
        std::unique_ptr<draco::PointCloud> pointCloudPtr(new draco::PointCloud());
        if (!pointCloudPtr) {
            NSLog(@"[DracoDecode] Failed to create point cloud");
            return nil;
        }
        
        // Use the appropriate decoding method
        // Try the direct decode-to-geometry approach
        auto status = _decoder->DecodeBufferToGeometry(&buffer, pointCloudPtr.get());
        
        if (!status.ok()) {
            NSLog(@"[DracoDecode] Failed to decode point cloud: %s", status.error_msg());
            return nil;
        }
        
        // Check if the point cloud has points
        if (!pointCloudPtr || pointCloudPtr->num_points() == 0) {
            NSLog(@"[DracoDecode] Decoded point cloud is empty");
            return nil;
        }
        
        NSLog(@"[DracoDecode] Successfully decoded point cloud with %d points", 
              pointCloudPtr->num_points());
        
        // Create a new wrapper object
        DracoPointCloud *dracoPointCloud = [[DracoPointCloud alloc] init];
        if (!dracoPointCloud) {
            NSLog(@"[DracoDecode] Failed to create DracoPointCloud wrapper object");
            return nil;
        }
        
        // Access the internal C++ object using Objective-C runtime
        Ivar ivar = class_getInstanceVariable([DracoPointCloud class], "_pointCloud");
        if (!ivar) {
            NSLog(@"[DracoDecode] Failed to access _pointCloud instance variable");
            return nil;
        }
        
        // Delete the default point cloud that was created in the init method
        draco::PointCloud* existingPointCloud = (__bridge draco::PointCloud*)object_getIvar(dracoPointCloud, ivar);
        if (existingPointCloud) {
            delete existingPointCloud;
        }
        
        // Release ownership from the unique_ptr and set it in our wrapper
        draco::PointCloud* rawPointCloud = pointCloudPtr.release();
        object_setIvar(dracoPointCloud, ivar, (__bridge id)rawPointCloud);
        
        NSLog(@"[DracoDecode] Successfully created and populated DracoPointCloud wrapper");
        return dracoPointCloud;
    }
    @catch (NSException *exception) {
        NSLog(@"[DracoDecode] Exception during decoding: %@", exception);
        return nil;
    }
}

// Swift-friendly method name that matches what's used in Swift code
- (nullable DracoPointCloud *)decodePointCloud:(NSData *)from {
    return [self decodePointCloudFromData:from];
}

- (void)setSkipAttributeTransform:(NSInteger)attributeType {
    if (_decoder) {
        // Cast to the expected GeometryAttribute::Type enum
        _decoder->SetSkipAttributeTransform(static_cast<draco::GeometryAttribute::Type>(attributeType));
    }
}

@end 