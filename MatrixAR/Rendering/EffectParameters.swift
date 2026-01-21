// EffectParameters.swift
// Runtime-adjustable parameters for the Matrix rain effect

import simd
import Combine

/// Runtime-adjustable parameters for the Matrix rain effect
final class EffectParameters: ObservableObject {

    // MARK: - Published Properties

    /// Characters per world unit (affects density of the rain)
    @Published var characterDensity: Float = 2.0 {
        didSet { characterDensity = characterDensity.clamped(to: 0.5...5.0) }
    }

    /// Speed multiplier for falling characters
    @Published var fallSpeed: Float = 1.0 {
        didSet { fallSpeed = fallSpeed.clamped(to: 0.1...3.0) }
    }

    /// Intensity of the glow/bloom effect
    @Published var glowIntensity: Float = 0.8 {
        didSet { glowIntensity = glowIntensity.clamped(to: 0.0...2.0) }
    }

    /// Primary color of the rain (RGB, normalized)
    @Published var baseColor: simd_float3 = simd_float3(0.0, 1.0, 0.3)

    /// Color of the leading edge characters
    @Published var highlightColor: simd_float3 = simd_float3(0.7, 1.0, 0.8)

    /// Scale of individual characters
    @Published var characterScale: Float = 1.0 {
        didSet { characterScale = characterScale.clamped(to: 0.5...2.0) }
    }

    /// Length of the fading trail behind each drop
    @Published var trailLength: Float = 8.0 {
        didSet { trailLength = trailLength.clamped(to: 1.0...20.0) }
    }

    // MARK: - Internal Properties

    /// Current time value (updated each frame)
    private(set) var time: Float = 0.0

    /// Random seed that changes periodically for variation
    private(set) var randomSeed: Float = Float.random(in: 0...1000)

    // MARK: - Methods

    /// Updates time-based parameters (call each frame)
    func update(deltaTime: Float) {
        time += deltaTime

        // Update random seed occasionally for subtle variation
        // This creates new "drops" starting at different positions
        if Int(time * 10) % 50 == 0 {
            randomSeed = Float.random(in: 0...1000)
        }
    }

    /// Resets all parameters to defaults
    func reset() {
        characterDensity = 2.0
        fallSpeed = 1.0
        glowIntensity = 0.8
        baseColor = simd_float3(0.0, 1.0, 0.3)
        highlightColor = simd_float3(0.7, 1.0, 0.8)
        characterScale = 1.0
        trailLength = 8.0
        time = 0.0
        randomSeed = Float.random(in: 0...1000)
    }

    /// Resets only the time (useful when resuming)
    func resetTime() {
        time = 0.0
    }

    /// Packs parameters into an array suitable for shader uniforms
    /// Must match the order expected in MatrixRain.metal
    func toShaderArray(surfaceType: Int = 0) -> [Float] {
        [
            time,                    // [0] time
            characterDensity,        // [1] density
            fallSpeed,               // [2] speed
            glowIntensity,           // [3] glow
            baseColor.x,             // [4] baseColor.r
            baseColor.y,             // [5] baseColor.g
            baseColor.z,             // [6] baseColor.b
            highlightColor.x,        // [7] highlightColor.r
            highlightColor.y,        // [8] highlightColor.g
            highlightColor.z,        // [9] highlightColor.b
            characterScale,          // [10] charScale
            trailLength,             // [11] trailLength
            randomSeed,              // [12] randomSeed
            Float(surfaceType),      // [13] surfaceType
            0,                       // [14] reserved
            0                        // [15] reserved
        ]
    }
}

// MARK: - Color Presets

extension EffectParameters {

    /// Classic Matrix green
    static var classicGreen: (base: simd_float3, highlight: simd_float3) {
        (simd_float3(0.0, 1.0, 0.3), simd_float3(0.7, 1.0, 0.8))
    }

    /// Blue variant
    static var blue: (base: simd_float3, highlight: simd_float3) {
        (simd_float3(0.0, 0.5, 1.0), simd_float3(0.5, 0.8, 1.0))
    }

    /// Red variant
    static var red: (base: simd_float3, highlight: simd_float3) {
        (simd_float3(1.0, 0.2, 0.1), simd_float3(1.0, 0.6, 0.5))
    }

    /// Purple variant
    static var purple: (base: simd_float3, highlight: simd_float3) {
        (simd_float3(0.6, 0.2, 1.0), simd_float3(0.8, 0.6, 1.0))
    }

    /// Golden variant
    static var gold: (base: simd_float3, highlight: simd_float3) {
        (simd_float3(1.0, 0.8, 0.0), simd_float3(1.0, 1.0, 0.7))
    }

    /// Applies a color preset
    func applyColorPreset(_ preset: (base: simd_float3, highlight: simd_float3)) {
        baseColor = preset.base
        highlightColor = preset.highlight
    }
}
