#include <metal_stdlib>
using namespace metal;

namespace SpacetimeMic {
    kernel void depthToColorKernelImpl(
        texture2d<float, access::read> depthTexture [[texture(0)]],
        texture2d<float, access::write> outputTexture [[texture(1)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        // Check if we're within the texture bounds
        if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
            return;
        }
        
        // Read the depth value from the depth texture at the current position
        float rawDepth = depthTexture.read(gid).r;
        
        // Define the maximum depth for normalization (3 meters)
        float maxDepthInMeters = 3.0;
        
        // Normalize the depth value between 0 and 1
        float normalizedDepth = clamp(rawDepth / maxDepthInMeters, 0.0, 1.0);
        
        // Initialize the color variable
        float4 color;
        
        // Map normalized depth to a color using a heatmap scheme
        if (normalizedDepth < 0.2) {
            // Blue to cyan - closest objects (0-2 feet)
            color = mix(float4(0.0, 0.0, 1.0, 1.0), float4(0.0, 1.0, 1.0, 1.0), normalizedDepth * 5.0);
        } else if (normalizedDepth < 0.4) {
            // Cyan to green (2-4 feet)
            color = mix(float4(0.0, 1.0, 1.0, 1.0), float4(0.0, 1.0, 0.0, 1.0), (normalizedDepth - 0.2) * 5.0);
        } else if (normalizedDepth < 0.6) {
            // Green to yellow (4-6 feet)
            color = mix(float4(0.0, 1.0, 0.0, 1.0), float4(1.0, 1.0, 0.0, 1.0), (normalizedDepth - 0.4) * 5.0);
        } else if (normalizedDepth < 0.8) {
            // Yellow to red (6-8 feet)
            color = mix(float4(1.0, 1.0, 0.0, 1.0), float4(1.0, 0.0, 0.0, 1.0), (normalizedDepth - 0.6) * 5.0);
        } else {
            // Red to white (8-10 feet)
            color = mix(float4(1.0, 0.0, 0.0, 1.0), float4(1.0, 1.0, 1.0, 1.0), (normalizedDepth - 0.8) * 5.0);
        }
        
        // Adjust alpha for depths exceeding the maximum
        if (rawDepth > maxDepthInMeters) {
            color.a = 0.3;
        }
        
        // Write the resulting color to the output texture
        outputTexture.write(color, gid);
    }
} 