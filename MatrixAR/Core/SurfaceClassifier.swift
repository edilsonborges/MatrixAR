// SurfaceClassifier.swift
// Handles surface classification for walls, floors, and ceilings

import ARKit
import simd

/// Classifies surfaces based on ARKit classification and geometry analysis
final class SurfaceClassifier {

    // MARK: - Types

    enum SurfaceType: Int {
        case wall = 0
        case floor = 1
        case ceiling = 2
        case unknown = 3

        var description: String {
            switch self {
            case .wall: return "Wall"
            case .floor: return "Floor"
            case .ceiling: return "Ceiling"
            case .unknown: return "Unknown"
            }
        }
    }

    // MARK: - Classification Methods

    /// Classifies a mesh anchor based on its dominant ARKit classification
    static func classify(meshAnchor: MeshAnchor) -> SurfaceType {
        let dominant = meshAnchor.dominantClassification

        switch dominant {
        case .wall, .door, .window:
            return .wall
        case .floor:
            return .floor
        case .ceiling:
            return .ceiling
        case .table, .seat:
            // Tables and seats are horizontal surfaces at varying heights
            return classifyByGeometry(meshAnchor: meshAnchor)
        case .none:
            // No classification available, use geometry-based classification
            return classifyByGeometry(meshAnchor: meshAnchor)
        @unknown default:
            return classifyByGeometry(meshAnchor: meshAnchor)
        }
    }

    /// Classifies a surface based on its geometric properties (normal direction)
    static func classifyByGeometry(meshAnchor: MeshAnchor) -> SurfaceType {
        // Get the average normal of the mesh
        let normals = meshAnchor.normals
        guard !normals.isEmpty else { return .unknown }

        // Calculate average normal
        var avgNormal = simd_float3.zero
        for normal in normals {
            avgNormal += normal
        }
        avgNormal /= Float(normals.count)
        avgNormal = simd_normalize(avgNormal)

        // Transform normal to world space
        let transform = meshAnchor.transform
        let worldNormal = simd_normalize(simd_float3(
            transform.columns.0.x * avgNormal.x + transform.columns.1.x * avgNormal.y + transform.columns.2.x * avgNormal.z,
            transform.columns.0.y * avgNormal.x + transform.columns.1.y * avgNormal.y + transform.columns.2.y * avgNormal.z,
            transform.columns.0.z * avgNormal.x + transform.columns.1.z * avgNormal.y + transform.columns.2.z * avgNormal.z
        ))

        // Classify based on the dot product with the up vector
        let upVector = simd_float3(0, 1, 0)
        let dotProduct = simd_dot(worldNormal, upVector)

        // Thresholds for classification
        let horizontalThreshold: Float = 0.7  // cos(45°) ≈ 0.707

        if dotProduct > horizontalThreshold {
            // Normal points up - this is a floor
            return .floor
        } else if dotProduct < -horizontalThreshold {
            // Normal points down - this is a ceiling
            return .ceiling
        } else {
            // Normal is mostly horizontal - this is a wall
            return .wall
        }
    }

    /// Classifies a single face based on its normal
    static func classify(normal: simd_float3, transform: simd_float4x4) -> SurfaceType {
        // Transform normal to world space
        let worldNormal = simd_normalize(simd_float3(
            transform.columns.0.x * normal.x + transform.columns.1.x * normal.y + transform.columns.2.x * normal.z,
            transform.columns.0.y * normal.x + transform.columns.1.y * normal.y + transform.columns.2.y * normal.z,
            transform.columns.0.z * normal.x + transform.columns.1.z * normal.y + transform.columns.2.z * normal.z
        ))

        let upVector = simd_float3(0, 1, 0)
        let dotProduct = simd_dot(worldNormal, upVector)

        let horizontalThreshold: Float = 0.7

        if dotProduct > horizontalThreshold {
            return .floor
        } else if dotProduct < -horizontalThreshold {
            return .ceiling
        } else {
            return .wall
        }
    }

    /// Returns classification counts for a mesh anchor
    static func classificationHistogram(for meshAnchor: MeshAnchor) -> [ARMeshClassification: Int] {
        guard meshAnchor.geometry.classification != nil else {
            return [:]
        }

        let faceCount = meshAnchor.geometry.faces.count
        var counts: [ARMeshClassification: Int] = [:]

        for i in 0..<faceCount {
            let classification = meshAnchor.classification(forFaceAt: i)
            counts[classification, default: 0] += 1
        }

        return counts
    }

    /// Calculates what percentage of faces belong to each surface type
    static func surfaceTypeDistribution(for meshAnchor: MeshAnchor) -> [SurfaceType: Float] {
        let histogram = classificationHistogram(for: meshAnchor)
        let total = histogram.values.reduce(0, +)

        guard total > 0 else { return [:] }

        var distribution: [SurfaceType: Float] = [:]

        for (classification, count) in histogram {
            let surfaceType: SurfaceType
            switch classification {
            case .wall, .door, .window:
                surfaceType = .wall
            case .floor:
                surfaceType = .floor
            case .ceiling:
                surfaceType = .ceiling
            default:
                surfaceType = .unknown
            }

            distribution[surfaceType, default: 0] += Float(count) / Float(total)
        }

        return distribution
    }
}
