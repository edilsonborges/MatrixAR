// MatrixARViewController.swift
// Main view controller for the Matrix AR experience

import UIKit
import ARKit
import RealityKit
import Combine

/// Main view controller for the Matrix AR experience
final class MatrixARViewController: UIViewController {

    // MARK: - Properties

    private var arSessionController: ARSessionController!
    private var entityManager: EntityManager!
    private var meshProcessor: MeshProcessor!
    private var materialFactory: MaterialFactory!
    private var textureManager: TextureManager!
    private var effectParameters: EffectParameters!

    private var cancellables = Set<AnyCancellable>()

    // UI Elements
    private var statusLabel: UILabel!
    private var controlPanelButton: UIButton!
    private var resetButton: UIButton!
    private var colorPresetButton: UIButton!

    // Status update timer
    private var statusUpdateTimer: Timer?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        checkCapabilities()
        setupComponents()
        setupUI()
        bindEvents()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        arSessionController.startSession()
        startStatusUpdates()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        arSessionController.pauseSession()
        stopStatusUpdates()
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }

    // MARK: - Setup

    private func checkCapabilities() {
        let capability = LiDARCapabilityChecker.deviceCapability

        switch capability {
        case .unsupported:
            showAlert(
                title: "AR Not Supported",
                message: "This device does not support AR experiences.",
                dismissAction: {
                    // Could exit or show limited mode
                }
            )
        case .partial:
            showAlert(
                title: "LiDAR Not Available",
                message: "This device does not have LiDAR. The Matrix effect requires LiDAR for mesh reconstruction. Some features will be unavailable.",
                dismissAction: nil
            )
        case .full:
            // Full capability - proceed normally
            print("Device has full LiDAR capability")
        }
    }

    private func setupComponents() {
        // Initialize effect parameters
        effectParameters = EffectParameters()

        // Initialize AR session controller
        arSessionController = ARSessionController(frame: view.bounds)
        view.addSubview(arSessionController.arView)
        arSessionController.arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Initialize Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }

        // Initialize texture manager and generate glyph atlas
        textureManager = TextureManager(device: device)
        do {
            try textureManager.generateGlyphAtlas()

            // Optionally save atlas for debugging
            #if DEBUG
            // try? textureManager.saveAtlasToFile(named: "GlyphAtlas_Debug")
            #endif
        } catch {
            print("Failed to generate glyph atlas: \(error)")
        }

        // Initialize material factory
        materialFactory = MaterialFactory(
            device: device,
            textureManager: textureManager,
            effectParameters: effectParameters
        )

        // Initialize mesh processor
        meshProcessor = MeshProcessor(materialFactory: materialFactory)

        // Initialize entity manager
        entityManager = EntityManager(
            arView: arSessionController.arView,
            meshProcessor: meshProcessor,
            effectParameters: effectParameters,
            materialFactory: materialFactory
        )

        // Subscribe to mesh updates
        entityManager.subscribeTo(meshUpdates: arSessionController.meshAnchorUpdates)

        print("All components initialized successfully")
        print("Material factory ready: \(materialFactory.isReady)")
    }

    private func setupUI() {
        // Status label (top left)
        statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textColor = UIColor(red: 0, green: 1, blue: 0.3, alpha: 1)
        statusLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        statusLabel.numberOfLines = 0
        statusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        statusLabel.layer.cornerRadius = 8
        statusLabel.clipsToBounds = true
        statusLabel.textAlignment = .left
        view.addSubview(statusLabel)

        // Control panel button (bottom right)
        controlPanelButton = createCircularButton(
            systemImage: "slider.horizontal.3",
            action: #selector(showControlPanel)
        )
        view.addSubview(controlPanelButton)

        // Reset button (bottom left)
        resetButton = createCircularButton(
            systemImage: "arrow.counterclockwise",
            action: #selector(resetSession)
        )
        view.addSubview(resetButton)

        // Color preset button (bottom center-left)
        colorPresetButton = createCircularButton(
            systemImage: "paintpalette",
            action: #selector(cycleColorPreset)
        )
        view.addSubview(colorPresetButton)

        // Layout constraints
        NSLayoutConstraint.activate([
            // Status label
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 200),

            // Control panel button
            controlPanelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            controlPanelButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            controlPanelButton.widthAnchor.constraint(equalToConstant: 50),
            controlPanelButton.heightAnchor.constraint(equalToConstant: 50),

            // Reset button
            resetButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            resetButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            resetButton.widthAnchor.constraint(equalToConstant: 50),
            resetButton.heightAnchor.constraint(equalToConstant: 50),

            // Color preset button
            colorPresetButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            colorPresetButton.leadingAnchor.constraint(equalTo: resetButton.trailingAnchor, constant: 16),
            colorPresetButton.widthAnchor.constraint(equalToConstant: 50),
            colorPresetButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func createCircularButton(systemImage: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false

        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        button.setImage(UIImage(systemName: systemImage, withConfiguration: config), for: .normal)

        button.tintColor = UIColor(red: 0, green: 1, blue: 0.3, alpha: 1)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        button.layer.cornerRadius = 25

        button.addTarget(self, action: action, for: .touchUpInside)

        return button
    }

    private func bindEvents() {
        // Track tracking state changes
        arSessionController.trackingStateChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleTrackingStateChange(state)
            }
            .store(in: &cancellables)

        // Track session errors
        arSessionController.sessionError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.handleSessionError(error)
            }
            .store(in: &cancellables)
    }

    // MARK: - Status Updates

    private func startStatusUpdates() {
        statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateStatusLabel()
        }
    }

    private func stopStatusUpdates() {
        statusUpdateTimer?.invalidate()
        statusUpdateTimer = nil
    }

    private func updateStatusLabel() {
        let stats = entityManager.sceneStatistics
        let lidarStatus = LiDARCapabilityChecker.supportsSceneReconstruction ? "On" : "Off"

        let statusText = """
          LiDAR: \(lidarStatus)
          Meshes: \(stats.meshCount)
          FPS: \(String(format: "%.0f", stats.fps))
          Mem: \(String(format: "%.0f", stats.memoryMB))MB
        """

        statusLabel.text = statusText
    }

    private func handleTrackingStateChange(_ state: ARCamera.TrackingState) {
        // Could show tracking state in UI if needed
        switch state {
        case .normal:
            break
        case .limited(let reason):
            switch reason {
            case .initializing:
                print("Tracking initializing...")
            case .excessiveMotion:
                print("Move slower for better tracking")
            case .insufficientFeatures:
                print("Need more visual features")
            case .relocalizing:
                print("Relocalizing...")
            @unknown default:
                break
            }
        case .notAvailable:
            print("Tracking not available")
        }
    }

    private func handleSessionError(_ error: Error) {
        showAlert(
            title: "AR Session Error",
            message: error.localizedDescription,
            dismissAction: nil
        )
    }

    // MARK: - Actions

    @objc private func showControlPanel() {
        let controlPanel = ControlPanelViewController(effectParameters: effectParameters)
        controlPanel.modalPresentationStyle = .pageSheet

        if let sheet = controlPanel.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }

        present(controlPanel, animated: true)
    }

    @objc private func resetSession() {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        entityManager.clearScene()
        arSessionController.resetSession()
        effectParameters.resetTime()
    }

    private var currentColorPresetIndex = 0
    private let colorPresets: [(name: String, preset: (base: simd_float3, highlight: simd_float3))] = [
        ("Green", EffectParameters.classicGreen),
        ("Blue", EffectParameters.blue),
        ("Red", EffectParameters.red),
        ("Purple", EffectParameters.purple),
        ("Gold", EffectParameters.gold)
    ]

    @objc private func cycleColorPreset() {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        currentColorPresetIndex = (currentColorPresetIndex + 1) % colorPresets.count
        let preset = colorPresets[currentColorPresetIndex]

        effectParameters.applyColorPreset(preset.preset)

        // Show brief toast
        showToast(message: preset.name)
    }

    // MARK: - Helpers

    private func showAlert(title: String, message: String, dismissAction: (() -> Void)?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            dismissAction?()
        })
        present(alert, animated: true)
    }

    private func showToast(message: String) {
        let toast = UILabel()
        toast.text = "  \(message)  "
        toast.textColor = .white
        toast.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        toast.font = .systemFont(ofSize: 14, weight: .medium)
        toast.layer.cornerRadius = 8
        toast.clipsToBounds = true
        toast.textAlignment = .center
        toast.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(toast)

        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -80)
        ])

        toast.alpha = 0
        UIView.animate(withDuration: 0.2) {
            toast.alpha = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            UIView.animate(withDuration: 0.3, animations: {
                toast.alpha = 0
            }) { _ in
                toast.removeFromSuperview()
            }
        }
    }
}
