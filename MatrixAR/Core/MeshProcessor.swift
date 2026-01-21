// MeshProcessor.swift
// Converts ARKit mesh anchors to RealityKit entities with Matrix materials

import ARKit
import RealityKit
import Combine

/// Converts ARKit mesh anchors to RealityKit entities with Matrix materials
final class MeshProcessor {

    // MARK: - Properties

    private let materialFactory: MaterialFactory
    private var meshEntities: [UUID: ModelEntity] = [:]
    private var meshSurfaceTypes: [UUID: SurfaceClassifier.SurfaceType] = [:]
    private var cancellables = Set<AnyCancellable>()

    weak var rootAnchor: AnchorEntity?

    /// Number of active mesh entities
    var meshCount: Int {
        meshEntities.count
    }

    // MARK: - Initialization

    init(materialFactory: MaterialFactory) {
        self.materialFactory = materialFactory
    }

    // MARK: - Mesh Processing

    /// Processes a mesh anchor update
    func processMeshUpdate(_ update: ARSessionController.MeshAnchorUpdate) {
        switch update.type {
        case .added:
            addMeshEntity(for: update.anchor)
        case .updated:
            updateMeshEntity(for: update.anchor)
        case .removed:
            removeMeshEntity(for: update.anchor.identifier)
        }
    }

    /// Creates a new mesh entity for the anchor
    private func addMeshEntity(for meshAnchor: MeshAnchor) {
        guard let entity = createMeshEntity(from: meshAnchor) else {
            return
        }

        meshEntities[meshAnchor.identifier] = entity
        rootAnchor?.addChild(entity)
    }

    /// Updates an existing mesh entity
    private func updateMeshEntity(for meshAnchor: MeshAnchor) {
        // For simplicity, remove and recreate
        // More sophisticated implementation could update geometry in place
        removeMeshEntity(for: meshAnchor.identifier)
        addMeshEntity(for: meshAnchor)
    }

    /// Removes a mesh entity
    private func removeMeshEntity(for identifier: UUID) {
        guard let entity = meshEntities.removeValue(forKey: identifier) else {
            return
        }
        meshSurfaceTypes.removeValue(forKey: identifier)
        entity.removeFromParent()
    }

    /// Creates a ModelEntity from mesh anchor geometry
    private func createMeshEntity(from meshAnchor: MeshAnchor) -> ModelEntity? {
        let geometry = meshAnchor.geometry

        // Create mesh descriptor from ARKit geometry
        guard let meshDescriptor = createMeshDescriptor(from: geometry, transform: meshAnchor.transform) else {
            return nil
        }

        do {
            let meshResource = try MeshResource.generate(from: [meshDescriptor])

            // Determine surface type from classifications
            let surfaceType = SurfaceClassifier.classify(meshAnchor: meshAnchor)
            meshSurfaceTypes[meshAnchor.identifier] = surfaceType

            // Get material for this surface type
            let material = materialFactory.createMaterial(for: surfaceType)

            let entity = ModelEntity(mesh: meshResource, materials: [material])

            // Apply anchor transform
            entity.transform = Transform(matrix: meshAnchor.transform)

            // Set name for debugging
            entity.name = "Mesh_\(meshAnchor.identifier.uuidString.prefix(8))_\(surfaceType.description)"

            return entity

        } catch {
            print("Failed to create mesh resource: \(error)")
            return nil
        }
    }

    /// Creates a MeshDescriptor from ARMeshGeometry
    private func createMeshDescriptor(from geometry: ARMeshGeometry, transform: simd_float4x4) -> MeshDescriptor? {
        // Extract vertices
        let vertexBuffer = geometry.vertices
        let vertexCount = vertexBuffer.count

        guard vertexCount > 0 else { return nil }

        var positions: [SIMD3<Float>] = []
        positions.reserveCapacity(vertexCount)

        let vertexStride = vertexBuffer.stride
        let vertexBaseAddress = vertexBuffer.buffer.contents()

        for i in 0..<vertexCount {
            let pointer = vertexBaseAddress.advanced(by: i * vertexStride)
            let vertex = pointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
            positions.append(vertex)
        }

        // Extract normals
        let normalBuffer = geometry.normals
        var normals: [SIMD3<Float>] = []
        normals.reserveCapacity(vertexCount)

        let normalStride = normalBuffer.stride
        let normalBaseAddress = normalBuffer.buffer.contents()

        for i in 0..<vertexCount {
            let pointer = normalBaseAddress.advanced(by: i * normalStride)
            let normal = pointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
            normals.append(normal)
        }

        // Extract indices
        let faceBuffer = geometry.faces
        let faceCount = faceBuffer.count
        let indicesPerFace = faceBuffer.indexCountPerPrimitive
        let indexCount = faceCount * indicesPerFace
        let bytesPerIndex = faceBuffer.bytesPerIndex

        var indices: [UInt32] = []
        indices.reserveCapacity(indexCount)

        let indexBaseAddress = faceBuffer.buffer.contents()

        for i in 0..<indexCount {
            let pointer = indexBaseAddress.advanced(by: i * bytesPerIndex)

            if bytesPerIndex == 4 {
                let index = pointer.assumingMemoryBound(to: UInt32.self).pointee
                indices.append(index)
            } else if bytesPerIndex == 2 {
                let index = pointer.assumingMemoryBound(to: UInt16.self).pointee
                indices.append(UInt32(index))
            }
        }

        // Generate texture coordinates
        // We use world-space position for triplanar mapping in the shader
        // but still provide basic UVs for compatibility
        var uvs: [SIMD2<Float>] = []
        uvs.reserveCapacity(vertexCount)

        for i in 0..<vertexCount {
            let pos = positions[i]
            // Simple planar projection - shader does the real triplanar work
            uvs.append(SIMD2<Float>(pos.x, pos.y))
        }

        // Create mesh descriptor
        var descriptor = MeshDescriptor(name: "ARMesh")
        descriptor.positions = MeshBuffer(positions)
        descriptor.normals = MeshBuffer(normals)
        descriptor.textureCoordinates = MeshBuffer(uvs)
        descriptor.primitives = .triangles(indices)

        return descriptor
    }

    /// Removes all mesh entities
    func removeAllMeshes() {
        for (_, entity) in meshEntities {
            entity.removeFromParent()
        }
        meshEntities.removeAll()
        meshSurfaceTypes.removeAll()
    }

    /// Updates materials on all existing entities
    func updateAllMaterials() {
        for (identifier, entity) in meshEntities {
            if let surfaceType = meshSurfaceTypes[identifier] {
                let material = materialFactory.createMaterial(for: surfaceType)
                entity.model?.materials = [material]
            }
        }
    }

    /// Updates materials with new time parameter for animation (call every frame)
    func updateMaterialsForAnimation() {
        // Get updated materials from factory
        let updatedMaterials = materialFactory.getUpdatedMaterials()

        // Apply to all entities
        for (identifier, entity) in meshEntities {
            if let surfaceType = meshSurfaceTypes[identifier],
               let material = updatedMaterials[surfaceType] {
                entity.model?.materials = [material]
            }
        }
    }

    /// Returns statistics about processed meshes
    var statistics: MeshStatistics {
        var wallCount = 0
        var floorCount = 0
        var ceilingCount = 0
        var unknownCount = 0

        for surfaceType in meshSurfaceTypes.values {
            switch surfaceType {
            case .wall: wallCount += 1
            case .floor: floorCount += 1
            case .ceiling: ceilingCount += 1
            case .unknown: unknownCount += 1
            }
        }

        return MeshStatistics(
            totalMeshes: meshEntities.count,
            wallMeshes: wallCount,
            floorMeshes: floorCount,
            ceilingMeshes: ceilingCount,
            unknownMeshes: unknownCount
        )
    }

    struct MeshStatistics {
        let totalMeshes: Int
        let wallMeshes: Int
        let floorMeshes: Int
        let ceilingMeshes: Int
        let unknownMeshes: Int
    }
}
