//
//  GeneratePoints.metal
//  spacetime-mic
//
//  Created by David Girardo on 3/12/25.
//

#include <metal_stdlib>
using namespace metal;


kernel void generatePoints(
    texture2d<float, access::read> depthTexture [[texture(0)]],
    device atomic_uint* counter [[buffer(0)]],
    device float3* points [[buffer(1)]],
    constant float4& intrinsics [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= depthTexture.get_width() || gid.y >= depthTexture.get_height()) return;
    
    float d = depthTexture.read(gid).r;
    if (d > 0) {
        float u = float(gid.x);
        float v = float(gid.y);
        float fx = intrinsics.x;
        float fy = intrinsics.y;
        float cx = intrinsics.z;
        float cy = intrinsics.w;
        
        float x = (u - cx) * d / fx;
        float y = (v - cy) * d / fy;
        float z = d;
        
        uint index = atomic_fetch_add_explicit(counter, 1, memory_order_relaxed);
        points[index] = float3(x, y, z);
    }
}
