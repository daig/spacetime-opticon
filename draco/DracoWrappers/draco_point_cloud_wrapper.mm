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
        _pointCloud->set_num_points(static_cast<draco::PointIndex::ValueType>(numPoints));
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

@end
