// LiDARCapabilityChecker.swift
// Checks device capabilities for LiDAR and scene reconstruction

import ARKit

/// Checks device capabilities for LiDAR and scene reconstruction
final class LiDARCapabilityChecker {

    enum Capability {
        case full           // LiDAR + scene reconstruction
        case partial        // AR tracking only, no mesh
        case unsupported    // No AR support
    }

    static var deviceCapability: Capability {
        guard ARWorldTrackingConfiguration.isSupported else {
            return .unsupported
        }

        // Check for scene reconstruction (requires LiDAR)
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            return .full
        }

        return .partial
    }

    static var supportsSceneReconstruction: Bool {
        ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }

    static var supportsClassification: Bool {
        ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification)
    }

    /// Human-readable capability description
    static var capabilityDescription: String {
        switch deviceCapability {
        case .full:
            return "LiDAR available - full mesh reconstruction enabled"
        case .partial:
            return "LiDAR not available - running in fallback mode"
        case .unsupported:
            return "AR not supported on this device"
        }
    }
}
