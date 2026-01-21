// MeshAnchor+Extensions.swift
// Extensions for ARMeshAnchor handling

import ARKit
import simd

// MARK: - MeshAnchor Wrapper

/// Wrapper for ARMeshAnchor providing convenient access to geometry data
struct MeshAnchor {
    let identifier: UUID
    let transform: simd_float4x4
    let geometry: ARMeshGeometry

    init(arMeshAnchor: ARMeshAnchor) {
        self.identifier = arMeshAnchor.identifier
        self.transform = arMeshAnchor.transform
        self.geometry = arMeshAnchor.geometry
    }

    /// Extracts vertices as an array of simd_float3
    var vertices: [simd_float3] {
        let vertexBuffer = geometry.vertices
        let vertexCount = vertexBuffer.count
        var result: [simd_float3] = []
        result.reserveCapacity(vertexCount)

        let stride = vertexBuffer.stride
        let baseAddress = vertexBuffer.buffer.contents()

        for i in 0..<vertexCount {
            let pointer = baseAddress.advanced(by: i * stride)
            let vertex = pointer.assumingMemoryBound(to: simd_float3.self).pointee
            result.append(vertex)
        }

        return result
    }

    /// Extracts normals as an array of simd_float3
    var normals: [simd_float3] {
        let normalBuffer = geometry.normals
        let normalCount = normalBuffer.count
        var result: [simd_float3] = []
        result.reserveCapacity(normalCount)

        let stride = normalBuffer.stride
        let baseAddress = normalBuffer.buffer.contents()

        for i in 0..<normalCount {
            let pointer = baseAddress.advanced(by: i * stride)
            let normal = pointer.assumingMemoryBound(to: simd_float3.self).pointee
            result.append(normal)
        }

        return result
    }

    /// Extracts face indices
    var faceIndices: [UInt32] {
        let indexBuffer = geometry.faces
        let faceCount = indexBuffer.count
        let indicesPerFace = indexBuffer.indexCountPerPrimitive
        var result: [UInt32] = []
        result.reserveCapacity(faceCount * indicesPerFace)

        let bytesPerIndex = indexBuffer.bytesPerIndex
        let baseAddress = indexBuffer.buffer.contents()

        for i in 0..<(faceCount * indicesPerFace) {
            let pointer = baseAddress.advanced(by: i * bytesPerIndex)

            // Handle different index sizes
            if bytesPerIndex == 4 {
                let index = pointer.assumingMemoryBound(to: UInt32.self).pointee
                result.append(index)
            } else if bytesPerIndex == 2 {
                let index = pointer.assumingMemoryBound(to: UInt16.self).pointee
                result.append(UInt32(index))
            }
        }

        return result
    }

    /// Gets classification for a face at given index
    func classification(forFaceAt index: Int) -> ARMeshClassification {
        guard let classificationBuffer = geometry.classification else {
            return .none
        }

        guard index < geometry.faces.count else {
            return .none
        }

        let pointer = classificationBuffer.buffer.contents()
            .assumingMemoryBound(to: UInt8.self)

        return ARMeshClassification(rawValue: Int(pointer[index])) ?? .none
    }

    /// Returns the dominant classification for this mesh anchor
    var dominantClassification: ARMeshClassification {
        guard geometry.classification != nil else {
            return .none
        }

        let faceCount = geometry.faces.count
        var classificationCounts: [ARMeshClassification: Int] = [:]

        for i in 0..<faceCount {
            let classification = self.classification(forFaceAt: i)
            classificationCounts[classification, default: 0] += 1
        }

        return classificationCounts.max { $0.value < $1.value }?.key ?? .none
    }

    /// Calculates the bounding box of the mesh
    var boundingBox: (min: simd_float3, max: simd_float3) {
        let verts = vertices
        guard !verts.isEmpty else {
            return (.zero, .zero)
        }

        var minPoint = verts[0]
        var maxPoint = verts[0]

        for vertex in verts {
            minPoint.x = min(minPoint.x, vertex.x)
            minPoint.y = min(minPoint.y, vertex.y)
            minPoint.z = min(minPoint.z, vertex.z)

            maxPoint.x = max(maxPoint.x, vertex.x)
            maxPoint.y = max(maxPoint.y, vertex.y)
            maxPoint.z = max(maxPoint.z, vertex.z)
        }

        return (minPoint, maxPoint)
    }

    /// Calculates the center of the mesh in local space
    var center: simd_float3 {
        let bounds = boundingBox
        return (bounds.min + bounds.max) * 0.5
    }

    /// Calculates the world-space center of the mesh
    var worldCenter: simd_float3 {
        let localCenter = simd_float4(center.x, center.y, center.z, 1.0)
        let worldCenter = transform * localCenter
        return simd_float3(worldCenter.x, worldCenter.y, worldCenter.z)
    }
}

// MARK: - ARMeshClassification Extensions

extension ARMeshClassification: CustomStringConvertible {
    public var description: String {
        switch self {
        case .none: return "None"
        case .wall: return "Wall"
        case .floor: return "Floor"
        case .ceiling: return "Ceiling"
        case .table: return "Table"
        case .seat: return "Seat"
        case .window: return "Window"
        case .door: return "Door"
        @unknown default: return "Unknown"
        }
    }

    /// Returns true if this is a vertical surface
    var isVertical: Bool {
        switch self {
        case .wall, .door, .window:
            return true
        default:
            return false
        }
    }

    /// Returns true if this is a horizontal surface
    var isHorizontal: Bool {
        switch self {
        case .floor, .ceiling, .table, .seat:
            return true
        default:
            return false
        }
    }
}
