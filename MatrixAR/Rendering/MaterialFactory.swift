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
    private var animatedTextureResource: TextureResource?
    private var cancellables = Set<AnyCancellable>()

    // Material cache
    private var materialCache: [SurfaceClassifier.SurfaceType: UnlitMaterial] = [:]

    // Current time for shader animation
    private var currentTime: Float = 0.0

    // Matrix animator for procedural animation
    private var matrixAnimator: MatrixAnimator?

    // Frame counter for texture updates (don't update every frame to save performance)
    private var frameCounter: Int = 0
    private let textureUpdateInterval: Int = 4 // Update texture every N frames (reduced for performance)

    // MARK: - Initialization

    init(device: MTLDevice, textureManager: TextureManager, effectParameters: EffectParameters) {
        self.device = device
        self.textureManager = textureManager
        self.effectParameters = effectParameters

        setupTextureResource()
        setupAnimator()
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

    private func setupAnimator() {
        matrixAnimator = MatrixAnimator(
            device: device,
            glyphAtlas: textureManager.glyphAtlas,
            atlasConfig: textureManager.atlasConfig
        )
        print("MaterialFactory: Matrix animator initialized")
    }

    private func observeParameterChanges() {
        effectParameters.objectWillChange
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
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

        let material = createAnimatedMaterial(for: surfaceType)
        materialCache[surfaceType] = material
        return material
    }

    /// Creates an animated Matrix material
    private func createAnimatedMaterial(for surfaceType: SurfaceClassifier.SurfaceType) -> UnlitMaterial {
        let baseColor = effectParameters.baseColor

        // Create base color
        let color = UIColor(
            red: CGFloat(baseColor.x),
            green: CGFloat(baseColor.y),
            blue: CGFloat(baseColor.z),
            alpha: 0.8
        )

        var material = UnlitMaterial(color: color)

        // Use animated texture if available, otherwise use static glyph atlas
        if let textureResource = animatedTextureResource ?? glyphTextureResource {
            material.color = UnlitMaterial.BaseColor(
                tint: .white.withAlphaComponent(0.9),
                texture: MaterialParameters.Texture(textureResource)
            )
        }

        // Configure blending for transparency
        material.blending = .transparent(opacity: .init(floatLiteral: 0.85))

        return material
    }

    // MARK: - Animation Updates

    /// Updates the animation and generates new texture - call every frame
    func updateTime(_ time: Float) {
        let deltaTime = time - currentTime
        currentTime = time

        // Update animator
        matrixAnimator?.update(deltaTime: deltaTime)

        // Update texture periodically (not every frame for performance)
        frameCounter += 1
        if frameCounter >= textureUpdateInterval {
            frameCounter = 0
            updateAnimatedTexture()
        }
    }

    /// Generates a new animated texture frame
    private func updateAnimatedTexture() {
        guard let animator = matrixAnimator else { return }

        // Generate new frame
        guard let cgImage = animator.generateTexture(
            baseColor: effectParameters.baseColor,
            highlightColor: effectParameters.highlightColor
        ) else {
            return
        }

        // Create texture resource from the generated image
        do {
            animatedTextureResource = try TextureResource.generate(
                from: cgImage,
                options: TextureResource.CreateOptions(semantic: .raw)
            )

            // Update all cached materials with new texture
            for (surfaceType, _) in materialCache {
                let material = createAnimatedMaterial(for: surfaceType)
                materialCache[surfaceType] = material
            }
        } catch {
            // Silently fail - will use previous frame or static texture
        }
    }

    /// Returns updated materials for all surface types
    func getUpdatedMaterials() -> [SurfaceClassifier.SurfaceType: Material] {
        var materials: [SurfaceClassifier.SurfaceType: Material] = [:]
        for (surfaceType, material) in materialCache {
            materials[surfaceType] = material
        }
        return materials
    }

    /// Invalidates the material cache, forcing recreation
    func invalidateCache() {
        materialCache.removeAll()
    }

    /// Returns whether the factory is ready to create materials
    var isReady: Bool {
        glyphTextureResource != nil || animatedTextureResource != nil
    }

    /// Returns whether animated materials are being used
    var isUsingCustomMaterials: Bool {
        matrixAnimator != nil
    }
}
