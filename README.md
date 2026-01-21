# Matrix AR

An iOS augmented reality application that projects the iconic "Matrix digital rain" effect onto real-world surfaces using LiDAR scanning.

## Requirements

- **Device**: iPhone 12 Pro or later, iPad Pro 2020 or later (LiDAR required for full functionality)
- **iOS**: 17.0 or later
- **Xcode**: 15.0 or later

## Features

- Real-time environment mesh reconstruction using LiDAR
- Surface classification (wall, floor, ceiling)
- Animated Matrix rain effect with customizable parameters
- Triplanar projection for proper UV mapping on arbitrary geometry
- Multiple color presets (Green, Blue, Red, Purple, Gold)
- 60 FPS target performance

## Project Structure

```
MatrixAR/
├── App/
│   ├── AppDelegate.swift           # Application delegate
│   ├── SceneDelegate.swift         # Scene lifecycle management
│   ├── Info.plist                  # App configuration
│   └── MatrixAR-Bridging-Header.h  # Swift/Metal bridging
├── Core/
│   ├── ARSessionController.swift   # AR session management
│   ├── MeshProcessor.swift         # Mesh anchor processing
│   ├── EntityManager.swift         # RealityKit entity lifecycle
│   └── SurfaceClassifier.swift     # Surface type detection
├── Rendering/
│   ├── EffectParameters.swift      # Runtime effect configuration
│   ├── TextureManager.swift        # Glyph atlas generation
│   └── MaterialFactory.swift       # CustomMaterial creation
├── Shaders/
│   ├── MatrixRain.metal            # Surface shader for Matrix effect
│   └── ShaderTypes.h               # Shared C/Metal types
├── Views/
│   ├── MatrixARViewController.swift    # Main view controller
│   └── ControlPanelViewController.swift # Parameter adjustment UI
└── Utilities/
    ├── LiDARCapabilityChecker.swift    # Device capability detection
    ├── PerformanceMonitor.swift        # FPS and memory tracking
    └── Extensions/
        ├── simd+Extensions.swift       # SIMD type utilities
        └── MeshAnchor+Extensions.swift # ARMeshAnchor helpers
```

## Setup Instructions

1. **Open the project in Xcode**:
   ```bash
   open MatrixAR.xcodeproj
   ```

2. **Configure signing**:
   - Select the MatrixAR target
   - Go to "Signing & Capabilities"
   - Select your development team

3. **Build and run**:
   - Connect a LiDAR-capable iOS device
   - Select your device as the build target
   - Press Cmd+R to build and run

## Usage

1. **Launch the app** on your LiDAR-capable device
2. **Move around** to let the LiDAR scan your environment
3. **Observe** the Matrix rain effect appearing on walls, floors, and ceilings
4. **Customize** the effect using the control panel (slider icon)
5. **Change colors** using the palette button
6. **Reset** the session using the refresh button

## Customizable Parameters

| Parameter | Range | Description |
|-----------|-------|-------------|
| Character Density | 0.5 - 5.0 | Characters per world unit |
| Fall Speed | 0.1 - 3.0 | Speed of falling characters |
| Glow Intensity | 0.0 - 2.0 | Emissive glow strength |
| Character Scale | 0.5 - 2.0 | Size of individual characters |
| Trail Length | 1.0 - 20.0 | Length of fading trail |

## Architecture

### Rendering Pipeline

1. ARKit provides mesh anchors from LiDAR scanning
2. MeshProcessor converts anchors to RealityKit ModelEntities
3. MaterialFactory creates CustomMaterials with the Matrix shader
4. EntityManager coordinates entity lifecycle and animation updates
5. The Metal surface shader computes triplanar projection and animates the effect

### Key Technologies

- **ARKit**: Scene reconstruction, world tracking
- **RealityKit**: Entity management, CustomMaterial
- **Metal**: Custom surface shaders for the Matrix effect
- **Combine**: Reactive updates and event handling

## Performance Considerations

- Glyph atlas uses mipmapping for efficient sampling at distance
- Triplanar projection computed in shader (no CPU UV generation)
- Display link ensures synchronized animation updates
- Materials cached by surface type to minimize recreation

## Troubleshooting

### "LiDAR Not Available" message
The app requires a LiDAR sensor for mesh reconstruction. It will still run but without the Matrix effect overlay.

### Low frame rate
- Reduce character density
- Lower glow intensity
- Ensure the device is not thermally throttled

### Mesh not appearing
- Ensure adequate lighting
- Move slowly to allow LiDAR scanning
- Reset the session using the refresh button

## License

This project is provided for educational purposes.

## Acknowledgments

- Inspired by the iconic visual effects from "The Matrix" (1999)
- Built with Apple's ARKit, RealityKit, and Metal frameworks
