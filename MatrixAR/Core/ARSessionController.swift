// ARSessionController.swift
// Manages ARSession configuration and lifecycle

import ARKit
import RealityKit
import Combine

/// Manages ARSession configuration and lifecycle
final class ARSessionController: NSObject {

    // MARK: - Properties

    private(set) var arView: ARView!
    private var meshAnchors: [UUID: MeshAnchor] = [:]
    private var cancellables = Set<AnyCancellable>()

    /// Publisher for mesh anchor updates
    let meshAnchorUpdates = PassthroughSubject<MeshAnchorUpdate, Never>()

    /// Publisher for tracking state changes
    let trackingStateChanged = PassthroughSubject<ARCamera.TrackingState, Never>()

    /// Publisher for session errors
    let sessionError = PassthroughSubject<Error, Never>()

    // MARK: - Types

    struct MeshAnchorUpdate {
        enum UpdateType {
            case added
            case updated
            case removed
        }
        let anchor: MeshAnchor
        let type: UpdateType
    }

    // MARK: - Initialization

    init(frame: CGRect) {
        super.init()
        configureARView(frame: frame)
    }

    // MARK: - Configuration

    private func configureARView(frame: CGRect) {
        arView = ARView(frame: frame)
        arView.session.delegate = self

        // Disable default AR coaching overlay for custom handling
        arView.automaticallyConfigureSession = false

        // Enable occlusion for proper depth compositing
        if LiDARCapabilityChecker.supportsSceneReconstruction {
            arView.environment.sceneUnderstanding.options.insert(.occlusion)
            // Optionally enable physics for the mesh
            // arView.environment.sceneUnderstanding.options.insert(.physics)
        }

        // Configure render options for performance
        arView.renderOptions = [
            .disablePersonOcclusion,      // Disable people occlusion for performance
            .disableMotionBlur,           // Disable motion blur
            .disableDepthOfField,         // Disable DoF for clarity
            .disableGroundingShadows      // Disable grounding shadows
        ]

        // Set background to camera feed
        arView.environment.background = .cameraFeed()

        // Debug visualization (disable in production)
        #if DEBUG
        // Uncomment to visualize scene understanding:
        // arView.debugOptions = [.showSceneUnderstanding, .showWorldOrigin]
        #endif
    }

    /// Starts the AR session with optimal configuration
    func startSession() {
        guard LiDARCapabilityChecker.deviceCapability != .unsupported else {
            print("AR not supported on this device")
            return
        }

        let configuration = ARWorldTrackingConfiguration()

        // Configure world tracking
        configuration.worldAlignment = .gravity
        configuration.planeDetection = [.horizontal, .vertical]

        // Enable scene reconstruction if available (requires LiDAR)
        if LiDARCapabilityChecker.supportsClassification {
            configuration.sceneReconstruction = .meshWithClassification
            print("Scene reconstruction with classification enabled")
        } else if LiDARCapabilityChecker.supportsSceneReconstruction {
            configuration.sceneReconstruction = .mesh
            print("Scene reconstruction enabled (without classification)")
        } else {
            print("Scene reconstruction not available - LiDAR required")
        }

        // Frame semantics for depth data
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }

        // Environmental texturing for realistic lighting
        configuration.environmentTexturing = .automatic

        // Light estimation
        configuration.isLightEstimationEnabled = true

        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        print("AR session started")
    }

    /// Pauses the AR session
    func pauseSession() {
        arView.session.pause()
        print("AR session paused")
    }

    /// Resets tracking and anchors
    func resetSession() {
        guard let configuration = arView.session.configuration else {
            startSession()
            return
        }

        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        meshAnchors.removeAll()
        print("AR session reset")
    }

    /// Returns the current camera transform
    var cameraTransform: simd_float4x4? {
        arView.session.currentFrame?.camera.transform
    }

    /// Returns the number of tracked mesh anchors
    var meshAnchorCount: Int {
        meshAnchors.count
    }
}

// MARK: - ARSessionDelegate

extension ARSessionController: ARSessionDelegate {

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                let wrapped = MeshAnchor(arMeshAnchor: meshAnchor)
                meshAnchors[meshAnchor.identifier] = wrapped
                meshAnchorUpdates.send(MeshAnchorUpdate(anchor: wrapped, type: .added))
            }
        }
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                let wrapped = MeshAnchor(arMeshAnchor: meshAnchor)
                meshAnchors[meshAnchor.identifier] = wrapped
                meshAnchorUpdates.send(MeshAnchorUpdate(anchor: wrapped, type: .updated))
            }
        }
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor,
               let cached = meshAnchors.removeValue(forKey: meshAnchor.identifier) {
                meshAnchorUpdates.send(MeshAnchorUpdate(anchor: cached, type: .removed))
            }
        }
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        trackingStateChanged.send(camera.trackingState)

        // Log tracking state changes for debugging
        switch camera.trackingState {
        case .normal:
            print("Tracking: Normal")
        case .limited(let reason):
            switch reason {
            case .initializing:
                print("Tracking: Initializing")
            case .excessiveMotion:
                print("Tracking: Limited - Excessive motion")
            case .insufficientFeatures:
                print("Tracking: Limited - Insufficient features")
            case .relocalizing:
                print("Tracking: Relocalizing")
            @unknown default:
                print("Tracking: Limited - Unknown reason")
            }
        case .notAvailable:
            print("Tracking: Not available")
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        print("AR Session failed: \(error.localizedDescription)")
        sessionError.send(error)

        // Attempt recovery for certain errors
        if let arError = error as? ARError {
            switch arError.code {
            case .worldTrackingFailed:
                // Try to restart session
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.resetSession()
                }
            default:
                break
            }
        }
    }

    func sessionWasInterrupted(_ session: ARSession) {
        print("AR Session was interrupted")
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        print("AR Session interruption ended")
        // Optionally reset session
        // resetSession()
    }
}
