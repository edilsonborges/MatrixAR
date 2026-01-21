// TextureManager.swift
// Manages glyph atlas texture generation and loading

import Metal
import MetalKit
import CoreGraphics
import UIKit

/// Manages glyph atlas texture generation and loading
final class TextureManager {

    // MARK: - Properties

    private let device: MTLDevice
    private let textureLoader: MTKTextureLoader

    /// The generated glyph atlas texture
    private(set) var glyphAtlas: MTLTexture?

    /// Atlas configuration
    struct AtlasConfig {
        let glyphsPerRow: Int = 16
        let glyphsPerColumn: Int = 16
        let glyphSize: Int = 64
        let fontSize: CGFloat = 48

        var textureSize: Int { glyphsPerRow * glyphSize }
        var totalGlyphs: Int { glyphsPerRow * glyphsPerColumn }
    }

    let atlasConfig = AtlasConfig()

    // Character sets for the Matrix rain
    // Katakana characters commonly seen in the Matrix
    private let katakana: [Character] = Array("アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲンガギグゲゴザジズゼゾダヂヅデドバビブベボパピプペポ")

    // ASCII characters and symbols
    private let ascii: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ@#$%&*+=<>?!{}[]|\\/:;'\"~`^")

    // MARK: - Initialization

    init(device: MTLDevice) {
        self.device = device
        self.textureLoader = MTKTextureLoader(device: device)
    }

    // MARK: - Atlas Generation

    /// Generates the glyph atlas texture
    func generateGlyphAtlas() throws {
        let size = atlasConfig.textureSize
        let glyphSize = atlasConfig.glyphSize

        // Create bitmap context with alpha
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw TextureError.contextCreationFailed
        }

        // Clear to transparent black
        context.setFillColor(UIColor.clear.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))

        // Configure text rendering
        // Use a monospace font that supports Japanese characters
        let font = UIFont(name: "HiraginoSans-W6", size: atlasConfig.fontSize)
            ?? UIFont(name: "Menlo-Bold", size: atlasConfig.fontSize)
            ?? UIFont.monospacedSystemFont(ofSize: atlasConfig.fontSize, weight: .bold)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white
        ]

        // Combine character sets
        var allGlyphs = katakana + ascii

        // Shuffle for more random distribution
        allGlyphs.shuffle()

        // Fill remaining slots with random characters if needed
        while allGlyphs.count < atlasConfig.totalGlyphs {
            if let randomChar = allGlyphs.randomElement() {
                allGlyphs.append(randomChar)
            }
        }

        // Draw each glyph
        UIGraphicsPushContext(context)

        for (index, glyph) in allGlyphs.prefix(atlasConfig.totalGlyphs).enumerated() {
            let row = index / atlasConfig.glyphsPerRow
            let col = index % atlasConfig.glyphsPerRow

            let x = CGFloat(col * glyphSize)
            // Flip Y for Core Graphics coordinate system (origin at bottom-left)
            let y = CGFloat((atlasConfig.glyphsPerColumn - 1 - row) * glyphSize)

            let cellRect = CGRect(x: x, y: y, width: CGFloat(glyphSize), height: CGFloat(glyphSize))

            let string = String(glyph)
            let attributedString = NSAttributedString(string: string, attributes: attributes)
            let stringSize = attributedString.size()

            // Center glyph in cell
            let drawX = x + (CGFloat(glyphSize) - stringSize.width) / 2
            let drawY = y + (CGFloat(glyphSize) - stringSize.height) / 2

            attributedString.draw(at: CGPoint(x: drawX, y: drawY))
        }

        UIGraphicsPopContext()

        // Create texture from context
        guard let cgImage = context.makeImage() else {
            throw TextureError.imageCreationFailed
        }

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: size,
            height: size,
            mipmapped: true
        )
        textureDescriptor.usage = [.shaderRead]
        textureDescriptor.storageMode = .shared

        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            throw TextureError.textureCreationFailed
        }

        // Copy image data to texture
        let region = MTLRegion(
            origin: MTLOrigin(x: 0, y: 0, z: 0),
            size: MTLSize(width: size, height: size, depth: 1)
        )

        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            throw TextureError.dataExtractionFailed
        }

        texture.replace(
            region: region,
            mipmapLevel: 0,
            withBytes: bytes,
            bytesPerRow: size * 4
        )

        // Generate mipmaps for better filtering at distance
        if let commandQueue = device.makeCommandQueue(),
           let commandBuffer = commandQueue.makeCommandBuffer(),
           let blitEncoder = commandBuffer.makeBlitCommandEncoder() {
            blitEncoder.generateMipmaps(for: texture)
            blitEncoder.endEncoding()
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }

        self.glyphAtlas = texture
        print("Glyph atlas generated: \(size)x\(size) with \(atlasConfig.totalGlyphs) glyphs")
    }

    /// Loads a pre-generated atlas from bundle
    func loadGlyphAtlas(named name: String) throws {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png") else {
            throw TextureError.resourceNotFound
        }

        let options: [MTKTextureLoader.Option: Any] = [
            .generateMipmaps: true,
            .SRGB: false,
            .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            .textureStorageMode: NSNumber(value: MTLStorageMode.shared.rawValue)
        ]

        glyphAtlas = try textureLoader.newTexture(URL: url, options: options)
        print("Glyph atlas loaded from bundle: \(name)")
    }

    /// Saves the generated atlas to a file (for debugging/preview)
    func saveAtlasToFile(named name: String) throws {
        guard let texture = glyphAtlas else {
            throw TextureError.textureCreationFailed
        }

        let size = texture.width

        // Read texture data
        var imageData = [UInt8](repeating: 0, count: size * size * 4)
        let region = MTLRegion(
            origin: MTLOrigin(x: 0, y: 0, z: 0),
            size: MTLSize(width: size, height: size, depth: 1)
        )

        texture.getBytes(
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
            throw TextureError.imageCreationFailed
        }

        // Save to documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent("\(name).png")

        let uiImage = UIImage(cgImage: cgImage)
        guard let pngData = uiImage.pngData() else {
            throw TextureError.dataExtractionFailed
        }

        try pngData.write(to: fileURL)
        print("Glyph atlas saved to: \(fileURL.path)")
    }

    // MARK: - Error Types

    enum TextureError: Error, LocalizedError {
        case contextCreationFailed
        case imageCreationFailed
        case textureCreationFailed
        case dataExtractionFailed
        case resourceNotFound

        var errorDescription: String? {
            switch self {
            case .contextCreationFailed: return "Failed to create graphics context"
            case .imageCreationFailed: return "Failed to create image from context"
            case .textureCreationFailed: return "Failed to create Metal texture"
            case .dataExtractionFailed: return "Failed to extract image data"
            case .resourceNotFound: return "Resource not found in bundle"
            }
        }
    }
}
