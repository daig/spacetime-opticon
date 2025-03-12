#include <metal_stdlib>
using namespace metal;
#include <CoreImage/CoreImage.h>

[[stitchable]]
float4 depthToColor(coreimage::sample_t depth) {
    float rawDepth = depth.r; // Depth map is single-channel, stored in red
    
    // Normalize depth (assuming max depth of 3 meters)
    float maxDepthInMeters = 3.0;
    float normalizedDepth = clamp(rawDepth / maxDepthInMeters, 0.0, 1.0);
    
    // Map to a heatmap color
    float4 color;
    if (normalizedDepth < 0.2) {
        color = mix(float4(0.0, 0.0, 1.0, 1.0), float4(0.0, 1.0, 1.0, 1.0), normalizedDepth * 5.0); // Blue to cyan
    } else if (normalizedDepth < 0.4) {
        color = mix(float4(0.0, 1.0, 1.0, 1.0), float4(0.0, 1.0, 0.0, 1.0), (normalizedDepth - 0.2) * 5.0); // Cyan to green
    } else if (normalizedDepth < 0.6) {
        color = mix(float4(0.0, 1.0, 0.0, 1.0), float4(1.0, 1.0, 0.0, 1.0), (normalizedDepth - 0.4) * 5.0); // Green to yellow
    } else if (normalizedDepth < 0.8) {
        color = mix(float4(1.0, 1.0, 0.0, 1.0), float4(1.0, 0.0, 0.0, 1.0), (normalizedDepth - 0.6) * 5.0); // Yellow to red
    } else {
        color = mix(float4(1.0, 0.0, 0.0, 1.0), float4(1.0, 1.0, 1.0, 1.0), (normalizedDepth - 0.8) * 5.0); // Red to white
    }
    
    // Fade out depths beyond max
    if (rawDepth > maxDepthInMeters) {
        color.a = 0.3;
    }
    
    return color;
}
