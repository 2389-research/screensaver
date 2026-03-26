// ABOUTME: Main ScreenSaverView that wires PaneControllers, layout engine, and chrome rendering.
// ABOUTME: Manages the full animation loop: init, start, animate frames, stop, and configure sheet.

import AppKit
import ScreenSaver
import CoreText
import IOKit.ps

public class ClaudeCodeScreenSaverView: ScreenSaverView {

    // MARK: - Constants

    private static let bundleID = "com.2389.ClaudeCodeScreenSaver"
    private static let statusBarHeightPadding: CGFloat = 4.0
    private static let maxDeltaTime: TimeInterval = 0.200
    private static let oledPixelShiftInterval: TimeInterval = 30.0
    private static let oledPixelShiftAmount: CGFloat = 2.0

    // MARK: - State

    private var animationActive = false
    private var paneControllers: [PaneController] = []
    private var layoutEngine: TmuxLayoutEngine?
    private var chromeRenderer: TmuxChromeRenderer?
    private var preferences = Preferences()
    private var theme: ThemeColors = .dark
    private var lastFrameTime: TimeInterval = 0
    private var activePaneIndex: Int = 0

    // Stagger state
    private var staggerDelays: [TimeInterval] = []
    private var staggerTimer: TimeInterval = 0
    private var paneActivated: [Bool] = []

    // Evolution state
    private var evolutionTimer: TimeInterval = 0
    private var evolutionTarget: TimeInterval = 60

    // OLED state
    private var oledShiftTimer: TimeInterval = 0
    private var oledShiftOffset: CGPoint = .zero

    // Layer references
    private var rootLayer: CALayer?
    private var statusBarLayer: CALayer?
    private var statusBarRightLayer: CATextLayer?
    private var borderLayers: [CATextLayer] = []

    // Session data
    private var loadedSessions: [(events: [SessionEvent], fileName: String)] = []

    // RNG seed derived from screen for multi-display
    private var displaySeed: UInt64 = 42

    // MARK: - Initialization

    public override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true

        preferences = PreferencesStorage.load(bundleIdentifier: Self.bundleID)
        theme = preferences.colorScheme == .dark ? .dark : .light

        // Derive seed from screen identifier for multi-display determinism
        if let screenNumber = window?.screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 {
            displaySeed = UInt64(screenNumber)
        } else {
            displaySeed = UInt64(frame.origin.x.hashValue &+ frame.origin.y.hashValue)
        }

        let onBattery = Self.isOnBattery()
        let fps: TimeInterval = (isPreview || onBattery) ? (1.0 / 15.0) : (1.0 / 30.0)
        animationTimeInterval = fps
    }

    // MARK: - ScreenSaverView Overrides

    public override func startAnimation() {
        super.startAnimation()
        guard !animationActive else { return }
        animationActive = true

        let root = self.layer ?? {
            let l = CALayer()
            self.layer = l
            return l
        }()
        self.rootLayer = root
        root.backgroundColor = NSColor(hex: theme.background).cgColor

        loadSessions()

        let onBattery = Self.isOnBattery()
        let paneCount = determinePaneCount(onBattery: onBattery)

        // Compute status bar metrics to know how much space panes get
        let statusFont = CTFontCreateWithName("Menlo" as CFString, 11.0, nil)
        let statusBarH = CTFontGetAscent(statusFont) + CTFontGetDescent(statusFont) + CTFontGetLeading(statusFont) + Self.statusBarHeightPadding

        let paneBounds = CGRect(
            x: bounds.minX,
            y: bounds.minY + statusBarH,
            width: bounds.width,
            height: bounds.height - statusBarH
        )

        layoutEngine = TmuxLayoutEngine(
            bounds: paneBounds,
            minPanes: max(2, paneCount - 2),
            maxPanes: paneCount,
            seed: displaySeed
        )

        let layouts = layoutEngine?.currentLayouts() ?? []

        // Create pane controllers with staggered start
        paneControllers = []
        staggerDelays = []
        paneActivated = []
        staggerTimer = 0

        for (index, layout) in layouts.enumerated() {
            let session = randomSession()
            let controller = PaneController(
                layout: layout,
                theme: theme,
                events: session.events,
                sessionFileName: session.fileName
            )
            paneControllers.append(controller)

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            root.addSublayer(controller.renderer.containerLayer)
            CATransaction.commit()

            // First pane starts immediately, others stagger
            let delay = index == 0 ? 0.0 : Double(index) * Double.random(in: 0.5...1.0)
            staggerDelays.append(delay)
            paneActivated.append(index == 0)
        }

        activePaneIndex = 0

        // Create chrome
        let firstName = paneControllers.first?.sessionFileName ?? "claude"
        let sessionName = firstName.replacingOccurrences(of: ".jsonl", with: "")
        chromeRenderer = TmuxChromeRenderer(
            sessionName: sessionName,
            windowCount: layouts.count,
            activeWindow: 0,
            lastWindow: max(layouts.count - 1, 0)
        )

        // Create status bar
        let statusLayer = chromeRenderer?.createStatusBarLayer(
            width: bounds.width, font: statusFont, theme: theme
        )
        if let statusLayer = statusLayer {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            root.addSublayer(statusLayer)
            CATransaction.commit()
            self.statusBarLayer = statusLayer
            // Find the right-side text layer for time updates
            if statusLayer.sublayers?.count ?? 0 > 1 {
                statusBarRightLayer = statusLayer.sublayers?[1] as? CATextLayer
            }
        }

        // Render border segments
        renderBorders(layouts: layouts, into: root)

        // Apply OLED-safe dimming
        if preferences.oledSafeMode {
            statusBarLayer?.opacity = 0.5
            for layer in borderLayers {
                layer.opacity = 0.5
            }
        }

        // Set evolution timer target
        evolutionTarget = TimeInterval.random(
            in: preferences.evolutionSpeedMin...preferences.evolutionSpeedMax
        )
        evolutionTimer = 0

        lastFrameTime = CACurrentMediaTime()
    }

    public override func animateOneFrame() {
        guard animationActive else { return }

        let now = CACurrentMediaTime()
        let rawDelta = now - lastFrameTime
        let deltaTime = min(max(rawDelta, 0), Self.maxDeltaTime)
        lastFrameTime = now

        // Update stagger timer and activate panes
        staggerTimer += deltaTime
        for i in 0..<paneControllers.count {
            if !paneActivated[i] && staggerTimer >= staggerDelays[i] {
                paneActivated[i] = true
            }
        }

        // Advance each active pane
        for (index, controller) in paneControllers.enumerated() {
            guard paneActivated[index] else { continue }
            controller.advance(deltaTime: deltaTime)

            // Check if pane just started typing a prompt — make it active
            if controller.isTypingPrompt && index != activePaneIndex {
                activePaneIndex = index
                chromeRenderer?.updateActiveWindow(index)
                updateBorderHighlights()
            }

            // If a pane finished, assign a new session
            if !controller.isPlaying {
                let session = randomSession()
                controller.assignSession(events: session.events, fileName: session.fileName)
            }
        }

        // Evolution timer: mutate layout periodically
        evolutionTimer += deltaTime
        if evolutionTimer >= evolutionTarget {
            evolutionTimer = 0
            evolutionTarget = TimeInterval.random(
                in: preferences.evolutionSpeedMin...preferences.evolutionSpeedMax
            )
            performEvolution()
        }

        // Update status bar time
        updateStatusBarTime()

        // OLED pixel shift
        if preferences.oledSafeMode {
            oledShiftTimer += deltaTime
            if oledShiftTimer >= Self.oledPixelShiftInterval {
                oledShiftTimer = 0
                applyOLEDPixelShift()
            }
        }
    }

    public override func stopAnimation() {
        guard animationActive else { return }
        animationActive = false

        // Clear all sublayers
        rootLayer?.sublayers?.forEach { $0.removeFromSuperlayer() }

        paneControllers = []
        layoutEngine = nil
        chromeRenderer = nil
        statusBarLayer = nil
        statusBarRightLayer = nil
        borderLayers = []
        staggerDelays = []
        paneActivated = []

        super.stopAnimation()
    }

    public override var hasConfigureSheet: Bool { true }

    public override var configureSheet: NSWindow? {
        let controller = PreferencesController(bundleIdentifier: Self.bundleID)
        let window = NSWindow(contentViewController: controller)
        window.title = "Claude Code Screensaver"
        return window
    }

    // MARK: - Session Loading

    private func loadSessions() {
        loadedSessions = []
        let bundle = Bundle(for: type(of: self))
        guard let urls = bundle.urls(forResourcesWithExtension: "jsonl", subdirectory: nil) else { return }
        for url in urls {
            let events = SessionParser.parseFile(at: url)
            guard !events.isEmpty else { continue }
            let fileName = url.lastPathComponent
            loadedSessions.append((events: events, fileName: fileName))
        }
    }

    private func randomSession() -> (events: [SessionEvent], fileName: String) {
        guard !loadedSessions.isEmpty else {
            // Fallback: a minimal synthetic session
            return (events: [.userPrompt(text: "hello"), .assistantText(text: "Hello! How can I help?")], fileName: "fallback.jsonl")
        }
        let index = Int.random(in: 0..<loadedSessions.count)
        return loadedSessions[index]
    }

    // MARK: - Pane Count

    private func determinePaneCount(onBattery: Bool) -> Int {
        if isPreview {
            return min(3, preferences.paneDensityMax)
        }
        if onBattery {
            return min(4, preferences.paneDensityMax)
        }
        return preferences.paneDensityMax
    }

    // MARK: - Border Rendering

    private func renderBorders(layouts: [PaneLayout], into root: CALayer) {
        borderLayers.forEach { $0.removeFromSuperlayer() }
        borderLayers = []

        guard let firstPaneMetrics = paneControllers.first?.renderer.fontMetrics else { return }
        let charAdvance = firstPaneMetrics.charAdvance
        let lineHeight = firstPaneMetrics.lineHeight

        let segments = BorderRenderer.computeSegments(
            layouts: layouts,
            totalBounds: layoutEngine?.currentLayouts().first?.frame ?? bounds,
            charAdvance: charAdvance,
            lineHeight: lineHeight
        )

        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let font = firstPaneMetrics.font as NSFont

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        for segment in segments {
            let layer = CATextLayer()
            layer.frame = CGRect(
                x: segment.position.x,
                y: segment.position.y,
                width: charAdvance,
                height: lineHeight
            )
            let color = segment.isAdjacentToActive
                ? NSColor(hex: theme.paneBorderActive)
                : NSColor(hex: theme.paneBorderInactive)
            layer.string = NSAttributedString(
                string: segment.character,
                attributes: [.font: font, .foregroundColor: color]
            )
            layer.contentsScale = scale
            layer.actions = ["contents": NSNull(), "string": NSNull()]
            root.addSublayer(layer)
            borderLayers.append(layer)
        }

        CATransaction.commit()
    }

    private func updateBorderHighlights() {
        guard let layoutEngine = layoutEngine else { return }
        let layouts = layoutEngine.currentLayouts()
        guard let firstPaneMetrics = paneControllers.first?.renderer.fontMetrics else { return }

        let segments = BorderRenderer.computeSegments(
            layouts: layouts,
            totalBounds: layouts.first?.frame ?? bounds,
            charAdvance: firstPaneMetrics.charAdvance,
            lineHeight: firstPaneMetrics.lineHeight
        )

        let font = firstPaneMetrics.font as NSFont

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        for (index, layer) in borderLayers.enumerated() {
            guard index < segments.count else { break }
            let segment = segments[index]
            let color = segment.isAdjacentToActive
                ? NSColor(hex: theme.paneBorderActive)
                : NSColor(hex: theme.paneBorderInactive)
            layer.string = NSAttributedString(
                string: segment.character,
                attributes: [.font: font, .foregroundColor: color]
            )
        }

        CATransaction.commit()
    }

    // MARK: - Evolution

    private func performEvolution() {
        guard let engine = layoutEngine else { return }

        // Pick a random mutation
        let roll = Int.random(in: 0..<3)
        switch roll {
        case 0: engine.trySplit()
        case 1: engine.tryClose()
        default: engine.tryResize()
        }

        // Rebuild pane controllers to match new layout
        rebuildPanesForLayout()
    }

    private func rebuildPanesForLayout() {
        guard let engine = layoutEngine, let root = rootLayer else { return }
        let layouts = engine.currentLayouts()

        // Remove old pane layers
        for controller in paneControllers {
            controller.renderer.containerLayer.removeFromSuperlayer()
        }

        let oldControllers = paneControllers
        paneControllers = []
        paneActivated = []
        staggerDelays = []

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        for (index, layout) in layouts.enumerated() {
            // Reuse existing controller if possible, otherwise create new
            let controller: PaneController
            if index < oldControllers.count {
                // Create a new controller but keep the session
                let old = oldControllers[index]
                controller = PaneController(
                    layout: layout,
                    theme: theme,
                    events: [],
                    sessionFileName: old.sessionFileName
                )
                // Assign a fresh session since we can't transfer state
                let session = randomSession()
                controller.assignSession(events: session.events, fileName: session.fileName)
            } else {
                let session = randomSession()
                controller = PaneController(
                    layout: layout,
                    theme: theme,
                    events: session.events,
                    sessionFileName: session.fileName
                )
            }
            root.addSublayer(controller.renderer.containerLayer)
            paneControllers.append(controller)
            paneActivated.append(true)
            staggerDelays.append(0)
        }

        CATransaction.commit()

        // Re-render borders
        renderBorders(layouts: layouts, into: root)

        if preferences.oledSafeMode {
            for layer in borderLayers {
                layer.opacity = 0.5
            }
        }
    }

    // MARK: - Status Bar

    private func updateStatusBarTime() {
        guard let rightLayer = statusBarRightLayer, let chrome = chromeRenderer else { return }
        let font = CTFontCreateWithName("Menlo" as CFString, 11.0, nil) as NSFont

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        rightLayer.string = NSAttributedString(
            string: chrome.statusBarRightText(),
            attributes: [.font: font, .foregroundColor: NSColor(hex: theme.statusBarText)]
        )
        CATransaction.commit()
    }

    // MARK: - OLED

    private func applyOLEDPixelShift() {
        let dx = CGFloat.random(in: -Self.oledPixelShiftAmount...Self.oledPixelShiftAmount)
        let dy = CGFloat.random(in: -Self.oledPixelShiftAmount...Self.oledPixelShiftAmount)
        oledShiftOffset = CGPoint(x: dx, y: dy)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        rootLayer?.transform = CATransform3DMakeTranslation(dx, dy, 0)
        CATransaction.commit()
    }

    // MARK: - Battery Detection

    static func isOnBattery() -> Bool {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any],
              !sources.isEmpty else {
            return false
        }
        // Check if any source is discharging
        for source in sources {
            if let desc = IOPSGetPowerSourceDescription(snapshot, source as CFTypeRef)?.takeUnretainedValue() as? [String: Any] {
                if let state = desc[kIOPSPowerSourceStateKey] as? String,
                   state == kIOPSBatteryPowerValue {
                    return true
                }
            }
        }
        return false
    }
}
