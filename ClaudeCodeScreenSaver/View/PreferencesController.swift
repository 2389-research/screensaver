// ABOUTME: NSViewController for the screensaver options panel (configureSheet).
// ABOUTME: Provides controls for color scheme, density, evolution speed, and OLED mode.

import AppKit
import ScreenSaver

class PreferencesController: NSViewController {
    private var preferences: Preferences
    private let bundleIdentifier: String

    // UI elements
    private let colorSchemeControl = NSSegmentedControl()
    private let densitySlider = NSSlider()
    private let densityLabel = NSTextField(labelWithString: "")
    private let evolutionSlider = NSSlider()
    private let evolutionLabel = NSTextField(labelWithString: "")
    private let okButton = NSButton(title: "OK", target: nil, action: nil)

    init(bundleIdentifier: String) {
        self.bundleIdentifier = bundleIdentifier
        self.preferences = PreferencesStorage.load(bundleIdentifier: bundleIdentifier)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 280))

        var y: CGFloat = 240

        // Title
        let title = NSTextField(labelWithString: "Claude Code Screensaver")
        title.font = NSFont.boldSystemFont(ofSize: 14)
        title.frame = NSRect(x: 20, y: y, width: 360, height: 20)
        container.addSubview(title)
        y -= 40

        // Color scheme
        let schemeLabel = NSTextField(labelWithString: "Color Scheme:")
        schemeLabel.frame = NSRect(x: 20, y: y, width: 120, height: 20)
        container.addSubview(schemeLabel)
        colorSchemeControl.segmentCount = 2
        colorSchemeControl.setLabel("Dark", forSegment: 0)
        colorSchemeControl.setLabel("Light", forSegment: 1)
        colorSchemeControl.selectedSegment = preferences.colorScheme == .dark ? 0 : 1
        colorSchemeControl.frame = NSRect(x: 150, y: y, width: 200, height: 24)
        colorSchemeControl.target = self
        colorSchemeControl.action = #selector(colorSchemeChanged)
        container.addSubview(colorSchemeControl)
        y -= 40

        // Pane density
        let densLabel = NSTextField(labelWithString: "Pane Density:")
        densLabel.frame = NSRect(x: 20, y: y, width: 120, height: 20)
        container.addSubview(densLabel)
        densitySlider.minValue = 3
        densitySlider.maxValue = 12
        densitySlider.integerValue = preferences.paneDensityMax
        densitySlider.frame = NSRect(x: 150, y: y, width: 160, height: 20)
        densitySlider.target = self
        densitySlider.action = #selector(densityChanged)
        container.addSubview(densitySlider)
        densityLabel.frame = NSRect(x: 320, y: y, width: 60, height: 20)
        densityLabel.stringValue = "\(preferences.paneDensityMax) panes"
        container.addSubview(densityLabel)
        y -= 40

        // Evolution speed
        let evoLabel = NSTextField(labelWithString: "Evolution Speed:")
        evoLabel.frame = NSRect(x: 20, y: y, width: 120, height: 20)
        container.addSubview(evoLabel)
        evolutionSlider.minValue = 30
        evolutionSlider.maxValue = 120
        evolutionSlider.doubleValue = preferences.evolutionSpeedMin
        evolutionSlider.frame = NSRect(x: 150, y: y, width: 160, height: 20)
        evolutionSlider.target = self
        evolutionSlider.action = #selector(evolutionChanged)
        container.addSubview(evolutionSlider)
        evolutionLabel.frame = NSRect(x: 320, y: y, width: 60, height: 20)
        evolutionLabel.stringValue = "\(Int(preferences.evolutionSpeedMin))s"
        container.addSubview(evolutionLabel)
        y -= 40

        // OK button
        okButton.frame = NSRect(x: 300, y: 10, width: 80, height: 30)
        okButton.bezelStyle = .rounded
        okButton.keyEquivalent = "\r"
        okButton.target = self
        okButton.action = #selector(dismissSheet)
        container.addSubview(okButton)

        self.view = container
    }

    @objc private func colorSchemeChanged() {
        preferences.colorScheme = colorSchemeControl.selectedSegment == 0 ? .dark : .light
        save()
    }

    @objc private func densityChanged() {
        preferences.paneDensityMax = densitySlider.integerValue
        densityLabel.stringValue = "\(densitySlider.integerValue) panes"
        save()
    }

    @objc private func evolutionChanged() {
        preferences.evolutionSpeedMin = evolutionSlider.doubleValue
        preferences.evolutionSpeedMax = evolutionSlider.doubleValue + 30
        evolutionLabel.stringValue = "\(Int(evolutionSlider.doubleValue))s"
        save()
    }

    @objc private func dismissSheet() {
        guard let window = view.window else { return }
        window.sheetParent?.endSheet(window)
    }

    private func save() {
        PreferencesStorage.save(preferences, bundleIdentifier: bundleIdentifier)
    }
}
