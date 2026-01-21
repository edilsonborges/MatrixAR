// ShaderTypes.h
// Bridging header for Swift ↔ Metal data structures

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

// Effect parameters passed to shader each frame
struct MatrixEffectParameters {
    float time;                    // Current time in seconds
    float characterDensity;        // Characters per unit (0.5 - 5.0)
    float fallSpeed;               // Fall speed multiplier (0.1 - 3.0)
    float glowIntensity;           // Bloom intensity (0.0 - 2.0)
    simd_float3 baseColor;         // Primary color (default: green)
    simd_float3 highlightColor;    // Leading edge color (brighter green/white)
    float characterScale;          // Glyph size multiplier
    float trailLength;             // Fade trail length (1.0 - 20.0)
    float randomSeed;              // Per-frame randomization
    int surfaceType;               // 0: wall, 1: floor, 2: ceiling
};

// Vertex data structure for mesh geometry
struct MeshVertex {
    simd_float3 position;
    simd_float3 normal;
    simd_float2 uv;
};

// Surface type enumeration
enum SurfaceType {
    SurfaceTypeWall = 0,
    SurfaceTypeFloor = 1,
    SurfaceTypeCeiling = 2,
    SurfaceTypeUnknown = 3
};

#endif /* ShaderTypes_h */
