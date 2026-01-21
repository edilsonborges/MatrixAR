// EntityManager.swift
// Manages the lifecycle of all RealityKit entities in the scene

import RealityKit
import ARKit
import Combine
import QuartzCore

/// Manages the lifecycle of all RealityKit entities in the scene
final class EntityManager {

    // MARK: - Properties

    private let arView: ARView
    private let meshProcessor: MeshProcessor
    private let effectParameters: EffectParameters
    private let materialFactory: MaterialFactory

    private var rootAnchor: AnchorEntity!
    private var cancellables = Set<AnyCancellable>()

    private var displayLink: CADisplayLink?
    private var lastUpdateTime: CFTimeInterval = 0

    private let performanceMonitor = PerformanceMonitor()

    // MARK: - Initialization

    init(arView: ARView,
         meshProcessor: MeshProcessor,
         effectParameters: EffectParameters,
         materialFactory: MaterialFactory) {
        self.arView = arView
        self.meshProcessor = meshProcessor
        self.effectParameters = effectParameters
        self.materialFactory = materialFactory

        setupRootAnchor()
        setupDisplayLink()
        setupMemoryWarningHandler()
    }

    deinit {
        displayLink?.invalidate()
    }

    // MARK: - Setup

    private func setupRootAnchor() {
        rootAnchor = AnchorEntity(world: .zero)
        arView.scene.addAnchor(rootAnchor)
        meshProcessor.rootAnchor = rootAnchor
    }

    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkUpdate))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(
            minimum: 30,
            maximum: 120,
            preferred: 60
        )
        displayLink?.add(to: .main, forMode: .common)
    }

    private func setupMemoryWarningHandler() {
        NotificationCenter.default.addObserver(
            forName: .performanceMemoryWarning,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }

    // MARK: - Frame Update

    @objc private func displayLinkUpdate(_ displayLink: CADisplayLink) {
        let currentTime = displayLink.timestamp
        let deltaTime = lastUpdateTime == 0 ? 0 : Float(currentTime - lastUpdateTime)
        lastUpdateTime = currentTime

        // Record frame for performance monitoring
        performanceMonitor.recordFrame()

        // Update effect parameters (time-based animation)
        effectParameters.update(deltaTime: deltaTime)

        // Update materials with new time values
        materialFactory.updateTime(effectParameters.time)
    }

    private func handleMemoryWarning() {
        print("EntityManager: Handling memory warning")
        // Could implement mesh LOD reduction or culling here
    }

    // MARK: - Mesh Subscription

    /// Subscribes to mesh anchor updates from the AR session
    func subscribeTo(meshUpdates: PassthroughSubject<ARSessionController.MeshAnchorUpdate, Never>) {
        meshUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                self?.meshProcessor.processMeshUpdate(update)
            }
            .store(in: &cancellables)
    }

    // MARK: - Scene Management

    /// Clears all mesh entities from the scene
    func clearScene() {
        meshProcessor.removeAllMeshes()
    }

    /// Forces a material update on all entities
    func refreshMaterials() {
        meshProcessor.updateAllMaterials()
    }

    /// Returns statistics about the current scene
    var sceneStatistics: SceneStatistics {
        let meshStats = meshProcessor.statistics

        return SceneStatistics(
            meshCount: meshStats.totalMeshes,
            wallMeshes: meshStats.wallMeshes,
            floorMeshes: meshStats.floorMeshes,
            ceilingMeshes: meshStats.ceilingMeshes,
            fps: performanceMonitor.currentFPS,
            memoryMB: performanceMonitor.memoryUsageMB
        )
    }

    struct SceneStatistics {
        let meshCount: Int
        let wallMeshes: Int
        let floorMeshes: Int
        let ceilingMeshes: Int
        let fps: Double
        let memoryMB: Double

        var formattedString: String {
            """
            Meshes: \(meshCount) (W:\(wallMeshes) F:\(floorMeshes) C:\(ceilingMeshes))
            FPS: \(String(format: "%.1f", fps))
            Memory: \(String(format: "%.1f", memoryMB)) MB
            """
        }
    }
}
