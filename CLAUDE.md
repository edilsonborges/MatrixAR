# Matrix AR - Project Guidelines

## Project Overview

iOS augmented reality app projecting Matrix digital rain onto real-world surfaces using LiDAR scanning. Built with ARKit, RealityKit, and Metal.

## Tech Stack

- **Language**: Swift (iOS 17.0+)
- **IDE**: Xcode 15.0+
- **Frameworks**: ARKit, RealityKit, Metal, Combine
- **Target**: iPhone 12 Pro+ / iPad Pro 2020+ (LiDAR required)

## Project Structure

```
MatrixAR/
├── App/          # App lifecycle (AppDelegate, SceneDelegate)
├── Core/         # AR session, mesh processing, entity management
├── Rendering/    # Effect parameters, textures, materials
├── Shaders/      # Metal shaders (.metal) and shared types
├── Views/        # View controllers and UI
└── Utilities/    # Helpers, extensions, performance monitoring
```

## Build & Run

```bash
open MatrixAR.xcodeproj
# Select LiDAR device target → Cmd+R
```

## Key Architecture

1. **ARSessionController** - Manages ARKit session and world tracking
2. **MeshProcessor** - Converts LiDAR mesh anchors to RealityKit entities
3. **MaterialFactory** - Creates CustomMaterials with Matrix shader
4. **EntityManager** - Entity lifecycle and animation updates
5. **MatrixRain.metal** - Surface shader with triplanar projection

## Code Conventions

- Use Swift's built-in concurrency (async/await) where applicable
- SIMD types for performance-critical math
- Combine for reactive event handling
- Keep shaders in `Shaders/` directory with shared types in `ShaderTypes.h`

## Performance Notes

- Target 60 FPS
- Cache materials by surface type
- Use glyph atlas with mipmapping
- Triplanar projection computed in shader (no CPU UV generation)
