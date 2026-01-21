// ControlPanelViewController.swift
// UI for adjusting Matrix effect parameters at runtime

import UIKit
import Combine
import simd

/// UI for adjusting Matrix effect parameters at runtime
final class ControlPanelViewController: UIViewController {

    // MARK: - Properties

    private let effectParameters: EffectParameters
    private var cancellables = Set<AnyCancellable>()

    // Sliders
    private var densitySlider: UISlider!
    private var speedSlider: UISlider!
    private var glowSlider: UISlider!
    private var scaleSlider: UISlider!
    private var trailSlider: UISlider!

    // Value Labels
    private var densityValueLabel: UILabel!
    private var speedValueLabel: UILabel!
    private var glowValueLabel: UILabel!
    private var scaleValueLabel: UILabel!
    private var trailValueLabel: UILabel!

    // Color preset buttons
    private var colorButtonsStack: UIStackView!

    // MARK: - Initialization

    init(effectParameters: EffectParameters) {
        self.effectParameters = effectParameters
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateSliderValues()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 24
        stackView.alignment = .fill
        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])

        // Title
        let titleLabel = UILabel()
        titleLabel.text = "Matrix Effect Controls"
        titleLabel.font = .boldSystemFont(ofSize: 22)
        titleLabel.textAlignment = .center
        stackView.addArrangedSubview(titleLabel)

        // Separator
        stackView.addArrangedSubview(createSeparator())

        // Color Presets Section
        let colorSectionLabel = createSectionLabel("Color Presets")
        stackView.addArrangedSubview(colorSectionLabel)

        colorButtonsStack = createColorPresetButtons()
        stackView.addArrangedSubview(colorButtonsStack)

        // Separator
        stackView.addArrangedSubview(createSeparator())

        // Effect Parameters Section
        let paramsSectionLabel = createSectionLabel("Effect Parameters")
        stackView.addArrangedSubview(paramsSectionLabel)

        // Density control
        let densityRow = createSliderRow(
            title: "Character Density",
            minValue: 0.5,
            maxValue: 5.0,
            initialValue: effectParameters.characterDensity,
            action: #selector(densityChanged)
        )
        densitySlider = densityRow.slider
        densityValueLabel = densityRow.valueLabel
        stackView.addArrangedSubview(densityRow.container)

        // Speed control
        let speedRow = createSliderRow(
            title: "Fall Speed",
            minValue: 0.1,
            maxValue: 3.0,
            initialValue: effectParameters.fallSpeed,
            action: #selector(speedChanged)
        )
        speedSlider = speedRow.slider
        speedValueLabel = speedRow.valueLabel
        stackView.addArrangedSubview(speedRow.container)

        // Glow control
        let glowRow = createSliderRow(
            title: "Glow Intensity",
            minValue: 0.0,
            maxValue: 2.0,
            initialValue: effectParameters.glowIntensity,
            action: #selector(glowChanged)
        )
        glowSlider = glowRow.slider
        glowValueLabel = glowRow.valueLabel
        stackView.addArrangedSubview(glowRow.container)

        // Scale control
        let scaleRow = createSliderRow(
            title: "Character Scale",
            minValue: 0.5,
            maxValue: 2.0,
            initialValue: effectParameters.characterScale,
            action: #selector(scaleChanged)
        )
        scaleSlider = scaleRow.slider
        scaleValueLabel = scaleRow.valueLabel
        stackView.addArrangedSubview(scaleRow.container)

        // Trail control
        let trailRow = createSliderRow(
            title: "Trail Length",
            minValue: 1.0,
            maxValue: 20.0,
            initialValue: effectParameters.trailLength,
            action: #selector(trailChanged)
        )
        trailSlider = trailRow.slider
        trailValueLabel = trailRow.valueLabel
        stackView.addArrangedSubview(trailRow.container)

        // Separator
        stackView.addArrangedSubview(createSeparator())

        // Reset button
        let resetButton = UIButton(type: .system)
        resetButton.setTitle("Reset to Defaults", for: .normal)
        resetButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        resetButton.setTitleColor(.systemRed, for: .normal)
        resetButton.addTarget(self, action: #selector(resetToDefaults), for: .touchUpInside)
        stackView.addArrangedSubview(resetButton)
    }

    private func createSectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .secondaryLabel
        label.textAlignment = .left
        return label
    }

    private func createSeparator() -> UIView {
        let separator = UIView()
        separator.backgroundColor = .separator
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return separator
    }

    private func createColorPresetButtons() -> UIStackView {
        let presets: [(name: String, color: UIColor, preset: (base: simd_float3, highlight: simd_float3))] = [
            ("Green", UIColor(red: 0, green: 1, blue: 0.3, alpha: 1), EffectParameters.classicGreen),
            ("Blue", UIColor(red: 0, green: 0.5, blue: 1, alpha: 1), EffectParameters.blue),
            ("Red", UIColor(red: 1, green: 0.2, blue: 0.1, alpha: 1), EffectParameters.red),
            ("Purple", UIColor(red: 0.6, green: 0.2, blue: 1, alpha: 1), EffectParameters.purple),
            ("Gold", UIColor(red: 1, green: 0.8, blue: 0, alpha: 1), EffectParameters.gold)
        ]

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 12

        for (index, preset) in presets.enumerated() {
            let button = UIButton(type: .system)
            button.backgroundColor = preset.color.withAlphaComponent(0.2)
            button.layer.cornerRadius = 8
            button.layer.borderWidth = 2
            button.layer.borderColor = preset.color.cgColor
            button.setTitle(preset.name, for: .normal)
            button.setTitleColor(preset.color, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
            button.tag = index
            button.addTarget(self, action: #selector(colorPresetTapped), for: .touchUpInside)

            button.heightAnchor.constraint(equalToConstant: 44).isActive = true

            stack.addArrangedSubview(button)
        }

        return stack
    }

    private func createSliderRow(
        title: String,
        minValue: Float,
        maxValue: Float,
        initialValue: Float,
        action: Selector
    ) -> (container: UIView, slider: UISlider, valueLabel: UILabel) {
        let container = UIView()

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 15)
        container.addSubview(titleLabel)

        let valueLabel = UILabel()
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.text = String(format: "%.2f", initialValue)
        valueLabel.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        valueLabel.textAlignment = .right
        valueLabel.textColor = .secondaryLabel
        container.addSubview(valueLabel)

        let slider = UISlider()
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.minimumValue = minValue
        slider.maximumValue = maxValue
        slider.value = initialValue
        slider.tintColor = UIColor(red: 0, green: 0.8, blue: 0.3, alpha: 1)
        slider.addTarget(self, action: action, for: .valueChanged)
        container.addSubview(slider)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),

            valueLabel.topAnchor.constraint(equalTo: container.topAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            valueLabel.widthAnchor.constraint(equalToConstant: 60),

            slider.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            slider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            slider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            slider.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return (container, slider, valueLabel)
    }

    private func updateSliderValues() {
        densitySlider?.value = effectParameters.characterDensity
        speedSlider?.value = effectParameters.fallSpeed
        glowSlider?.value = effectParameters.glowIntensity
        scaleSlider?.value = effectParameters.characterScale
        trailSlider?.value = effectParameters.trailLength

        densityValueLabel?.text = String(format: "%.2f", effectParameters.characterDensity)
        speedValueLabel?.text = String(format: "%.2f", effectParameters.fallSpeed)
        glowValueLabel?.text = String(format: "%.2f", effectParameters.glowIntensity)
        scaleValueLabel?.text = String(format: "%.2f", effectParameters.characterScale)
        trailValueLabel?.text = String(format: "%.2f", effectParameters.trailLength)
    }

    // MARK: - Actions

    @objc private func densityChanged(_ slider: UISlider) {
        effectParameters.characterDensity = slider.value
        densityValueLabel?.text = String(format: "%.2f", slider.value)
    }

    @objc private func speedChanged(_ slider: UISlider) {
        effectParameters.fallSpeed = slider.value
        speedValueLabel?.text = String(format: "%.2f", slider.value)
    }

    @objc private func glowChanged(_ slider: UISlider) {
        effectParameters.glowIntensity = slider.value
        glowValueLabel?.text = String(format: "%.2f", slider.value)
    }

    @objc private func scaleChanged(_ slider: UISlider) {
        effectParameters.characterScale = slider.value
        scaleValueLabel?.text = String(format: "%.2f", slider.value)
    }

    @objc private func trailChanged(_ slider: UISlider) {
        effectParameters.trailLength = slider.value
        trailValueLabel?.text = String(format: "%.2f", slider.value)
    }

    @objc private func colorPresetTapped(_ sender: UIButton) {
        let presets: [(base: simd_float3, highlight: simd_float3)] = [
            EffectParameters.classicGreen,
            EffectParameters.blue,
            EffectParameters.red,
            EffectParameters.purple,
            EffectParameters.gold
        ]

        guard sender.tag < presets.count else { return }

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        effectParameters.applyColorPreset(presets[sender.tag])
    }

    @objc private func resetToDefaults() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        effectParameters.reset()
        updateSliderValues()
    }
}
