// simd+Extensions.swift
// SIMD type extensions for convenience

import simd

// MARK: - simd_float3 Extensions

extension simd_float3 {
    /// Returns the length (magnitude) of the vector
    var length: Float {
        simd_length(self)
    }

    /// Returns a normalized version of this vector
    var normalized: simd_float3 {
        simd_normalize(self)
    }

    /// Dot product with another vector
    func dot(_ other: simd_float3) -> Float {
        simd_dot(self, other)
    }

    /// Cross product with another vector
    func cross(_ other: simd_float3) -> simd_float3 {
        simd_cross(self, other)
    }

    /// Linear interpolation to another vector
    func lerp(to: simd_float3, t: Float) -> simd_float3 {
        self + (to - self) * t
    }

    /// Creates a vector from a simd_float4 (discarding w component)
    init(_ v: simd_float4) {
        self.init(v.x, v.y, v.z)
    }
}

// MARK: - simd_float4x4 Extensions

extension simd_float4x4 {
    /// Returns the translation component of the matrix
    var translation: simd_float3 {
        simd_float3(columns.3.x, columns.3.y, columns.3.z)
    }

    /// Returns the scale component of the matrix (approximate)
    var scale: simd_float3 {
        simd_float3(
            simd_length(simd_float3(columns.0.x, columns.0.y, columns.0.z)),
            simd_length(simd_float3(columns.1.x, columns.1.y, columns.1.z)),
            simd_length(simd_float3(columns.2.x, columns.2.y, columns.2.z))
        )
    }

    /// Creates a translation matrix
    static func translation(_ t: simd_float3) -> simd_float4x4 {
        simd_float4x4(
            simd_float4(1, 0, 0, 0),
            simd_float4(0, 1, 0, 0),
            simd_float4(0, 0, 1, 0),
            simd_float4(t.x, t.y, t.z, 1)
        )
    }

    /// Creates a uniform scale matrix
    static func scale(_ s: Float) -> simd_float4x4 {
        simd_float4x4(
            simd_float4(s, 0, 0, 0),
            simd_float4(0, s, 0, 0),
            simd_float4(0, 0, s, 0),
            simd_float4(0, 0, 0, 1)
        )
    }

    /// Creates a non-uniform scale matrix
    static func scale(_ s: simd_float3) -> simd_float4x4 {
        simd_float4x4(
            simd_float4(s.x, 0, 0, 0),
            simd_float4(0, s.y, 0, 0),
            simd_float4(0, 0, s.z, 0),
            simd_float4(0, 0, 0, 1)
        )
    }

    /// Identity matrix
    static let identity = matrix_identity_float4x4
}

// MARK: - Float Extensions

extension Float {
    /// Clamps the value to a closed range
    func clamped(to range: ClosedRange<Float>) -> Float {
        min(max(self, range.lowerBound), range.upperBound)
    }

    /// Linear interpolation to another value
    func lerp(to: Float, t: Float) -> Float {
        self + (to - self) * t
    }

    /// Converts degrees to radians
    var radians: Float {
        self * .pi / 180.0
    }

    /// Converts radians to degrees
    var degrees: Float {
        self * 180.0 / .pi
    }
}

// MARK: - Comparable Extension

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
