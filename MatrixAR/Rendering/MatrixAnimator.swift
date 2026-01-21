// MatrixAnimator.swift
// Generates animated Matrix rain texture each frame

import UIKit
import Metal
import simd

/// Generates animated Matrix rain effect as a texture
final class MatrixAnimator {

    // MARK: - Properties

    private let device: MTLDevice
    private let glyphAtlas: MTLTexture?
    private let atlasConfig: TextureManager.AtlasConfig

    // Animation state
    private var time: Float = 0.0

    // Grid configuration
    private let columns: Int = 32
    private let rows: Int = 48

    // Per-column state for animation
    private var columnStates: [ColumnState] = []

    // Katakana and ASCII characters for display
    private let characters: [Character] = Array("アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲンガギグゲゴザジズゼゾダヂヅデドバビブベボパピプペポ0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    // Output texture size
    let textureSize: Int = 512

    // MARK: - Types

    struct ColumnState {
        var dropPosition: Float  // Current position of the leading edge (0 to rows)
        var speed: Float         // Fall speed (rows per second)
        var trailLength: Float   // Number of characters in the trail
        var glyphIndices: [Int]  // Glyph index for each row
        var glyphChangeTimer: Float
        var active: Bool         // Whether this column is currently showing rain

        init(rows: Int) {
            dropPosition = -Float.random(in: 0...20)
            speed = Float.random(in: 8...20)
            trailLength = Float.random(in: 5...15)
            glyphIndices = (0..<rows).map { _ in Int.random(in: 0..<256) }
            glyphChangeTimer = Float.random(in: 0...1)
            active = Float.random(in: 0...1) > 0.3
        }

        mutating func update(deltaTime: Float, rows: Int) {
            dropPosition += speed * deltaTime

            // Reset when drop falls off screen
            if dropPosition > Float(rows) + trailLength {
                dropPosition = -trailLength
                speed = Float.random(in: 8...20)
                trailLength = Float.random(in: 5...15)
                active = Float.random(in: 0...1) > 0.3
            }

            // Occasionally change glyphs for flickering effect
            glyphChangeTimer -= deltaTime
            if glyphChangeTimer <= 0 {
                let idx = Int.random(in: 0..<rows)
                glyphIndices[idx] = Int.random(in: 0..<256)
                glyphChangeTimer = Float.random(in: 0.1...0.5)
            }
        }
    }

    // MARK: - Initialization

    init(device: MTLDevice, glyphAtlas: MTLTexture?, atlasConfig: TextureManager.AtlasConfig) {
        self.device = device
        self.glyphAtlas = glyphAtlas
        self.atlasConfig = atlasConfig

        // Initialize column states
        for _ in 0..<columns {
            columnStates.append(ColumnState(rows: rows))
        }
    }

    // MARK: - Animation

    /// Updates animation state
    func update(deltaTime: Float) {
        time += deltaTime

        for i in 0..<columns {
            columnStates[i].update(deltaTime: deltaTime, rows: rows)
        }
    }

    /// Generates the animated Matrix texture
    func generateTexture(baseColor: simd_float3, highlightColor: simd_float3) -> CGImage? {
        let cellWidth = textureSize / columns
        let cellHeight = textureSize / rows

        // Create bitmap context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: textureSize,
            height: textureSize,
            bitsPerComponent: 8,
            bytesPerRow: textureSize * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        // Clear to transparent black
        context.setFillColor(UIColor.black.withAlphaComponent(0.0).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: textureSize, height: textureSize))

        UIGraphicsPushContext(context)

        // Draw each column
        for col in 0..<columns {
            let state = columnStates[col]
            guard state.active else { continue }

            let x = CGFloat(col * cellWidth)

            // Draw each cell in the column
            for row in 0..<rows {
                let y = CGFloat((rows - 1 - row) * cellHeight) // Flip Y for Core Graphics

                // Calculate distance from leading edge
                let distFromHead = state.dropPosition - Float(row)

                // Only draw if within the trail
                if distFromHead >= 0 && distFromHead < state.trailLength {
                    // Calculate brightness (leading edge is brightest)
                    let normalizedDist = distFromHead / state.trailLength
                    var brightness = 1.0 - normalizedDist
                    brightness = pow(brightness, 1.5) // Non-linear falloff

                    // Add some variation
                    let flicker = 0.8 + 0.2 * sin(time * 15 + Float(col) * 0.5 + Float(row) * 0.3)
                    brightness *= flicker

                    // Determine color (leading edge uses highlight color)
                    let isLeadingEdge = distFromHead < 2.0
                    let colorMix: Float = isLeadingEdge ? 0.8 : 0.0

                    let r = CGFloat(mix(baseColor.x, highlightColor.x, t: colorMix) * brightness)
                    let g = CGFloat(mix(baseColor.y, highlightColor.y, t: colorMix) * brightness)
                    let b = CGFloat(mix(baseColor.z, highlightColor.z, t: colorMix) * brightness)

                    let color = UIColor(red: r, green: g, blue: b, alpha: CGFloat(brightness))

                    // Get character for this cell
                    let glyphIndex = state.glyphIndices[row] % characters.count
                    let char = String(characters[glyphIndex])

                    // Draw the character
                    let font = UIFont(name: "HiraginoSans-W6", size: CGFloat(cellHeight) * 0.8)
                        ?? UIFont.monospacedSystemFont(ofSize: CGFloat(cellHeight) * 0.8, weight: .bold)

                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .foregroundColor: color
                    ]

                    let attributedString = NSAttributedString(string: char, attributes: attributes)
                    let stringSize = attributedString.size()

                    let drawX = x + (CGFloat(cellWidth) - stringSize.width) / 2
                    let drawY = y + (CGFloat(cellHeight) - stringSize.height) / 2

                    attributedString.draw(at: CGPoint(x: drawX, y: drawY))
                }
            }
        }

        UIGraphicsPopContext()

        return context.makeImage()
    }

    // MARK: - Helpers

    private func mix(_ a: Float, _ b: Float, t: Float) -> Float {
        return a + (b - a) * t
    }
}
