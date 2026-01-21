// MaterialFactory.swift
// Creates and manages materials for the Matrix effect

import RealityKit
import Metal
import MetalKit
import Combine
import UIKit

/// Creates and manages materials for the Matrix effect
final class MaterialFactory {

    // MARK: - Properties

    private let device: MTLDevice
    private let textureManager: TextureManager
    private let effectParameters: EffectParameters

    private var glyphTextureResource: TextureResource?
    private var cancellables = Set<AnyCancellable>()

    // Cache materials by surface type
    private var materialCache: [SurfaceClassifier.SurfaceType: Material] = [:]

    // Current time for shader animation
    private var currentTime: Float = 0.0

    // MARK: - Initialization

    init(device: MTLDevice, textureManager: TextureManager, effectParameters: EffectParameters) {
        self.device = device
        self.textureManager = textureManager
        self.effectParameters = effectParameters

        setupTextureResource()
        observeParameterChanges()
    }

    // MARK: - Setup

    private func setupTextureResource() {
        guard let mtlTexture = textureManager.glyphAtlas else {
            print("MaterialFactory: No glyph atlas available")
            return
        }

        do {
            let size = mtlTexture.width

            // Read texture data back from MTLTexture
            var imageData = [UInt8](repeating: 0, count: size * size * 4)
            let region = MTLRegion(
                origin: MTLOrigin(x: 0, y: 0, z: 0),
                size: MTLSize(width: size, height: size, depth: 1)
            )

            mtlTexture.getBytes(
                &imageData,
                bytesPerRow: size * 4,
                from: region,
                mipmapLevel: 0
            )

            // Create CGImage
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let context = CGContext(
                data: &imageData,
                width: size,
                height: size,
                bitsPerComponent: 8,
                bytesPerRow: size * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ),
            let cgImage = context.makeImage() else {
                print("MaterialFactory: Failed to create CGImage from texture")
                return
            }

            // Generate TextureResource from CGImage
            glyphTextureResource = try TextureResource.generate(
                from: cgImage,
                options: TextureResource.CreateOptions(semantic: .raw)
            )

            print("MaterialFactory: Glyph texture resource created successfully")

        } catch {
            print("MaterialFactory: Failed to create texture resource: \(error)")
        }
    }

    private func observeParameterChanges() {
        effectParameters.objectWillChange
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.invalidateCache()
            }
            .store(in: &cancellables)
    }

    // MARK: - Material Creation

    /// Creates a material for the specified surface type
    func createMaterial(for surfaceType: SurfaceClassifier.SurfaceType) -> Material {
        // Check cache
        if let cached = materialCache[surfaceType] {
            return cached
        }

        // Create fallback material with Matrix-style appearance
        let material = createMatrixMaterial(for: surfaceType)
        materialCache[surfaceType] = material
        return material
    }

    /// Creates a Matrix-style material using UnlitMaterial
    private func createMatrixMaterial(for surfaceType: SurfaceClassifier.SurfaceType) -> Material {
        let baseColor = effectParameters.baseColor

        // Create color with transparency
        let color = UIColor(
            red: CGFloat(baseColor.x),
            green: CGFloat(baseColor.y),
            blue: CGFloat(baseColor.z),
            alpha: 0.4
        )

        var material = UnlitMaterial(color: color)

        // Add glyph texture if available
        if let textureResource = glyphTextureResource {
            material.color = UnlitMaterial.BaseColor(
                tint: color,
                texture: MaterialParameters.Texture(textureResource)
            )
        }

        // Configure blending
        material.blending = .transparent(opacity: PhysicallyBasedMaterial.Opacity(floatLiteral: 0.5))

        return material
    }

    // MARK: - Material Updates

    /// Updates the time uniform for animation
    func updateTime(_ time: Float) {
        currentTime = time
        // For static materials, we don't need per-frame updates
        // The animated version would require CustomMaterial with working Metal Toolchain
    }

    /// Invalidates the material cache, forcing recreation
    func invalidateCache() {
        materialCache.removeAll()
    }

    /// Returns whether the factory is ready to create materials
    var isReady: Bool {
        glyphTextureResource != nil
    }
}
