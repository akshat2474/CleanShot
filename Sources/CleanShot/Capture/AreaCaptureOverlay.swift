import AppKit
import CoreGraphics

/// Interactive fullscreen capture overlay that manages area selection, modifier keys, loupe tracking, and window snapping.
@MainActor
public final class AreaCaptureOverlayWindow: NSWindow {

    public var onCaptureCompleted: ((NSImage?) -> Void)?

    private let snapshot: ScreenSnapshot
    private let primaryScreenHeight: CGFloat
    private let overlayView: AreaCaptureView

    public init(snapshot: ScreenSnapshot, primaryScreenHeight: CGFloat) {
        self.snapshot = snapshot
        self.primaryScreenHeight = primaryScreenHeight
        self.overlayView = AreaCaptureView(snapshot: snapshot, primaryScreenHeight: primaryScreenHeight)

        super.init(
            contentRect: snapshot.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: snapshot.screen
        )

        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) - 1)
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true

        self.contentView = overlayView
        self.overlayView.windowRef = self
    }

    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }
}

/// Content view handling drawing, mouse events, and key tracking during area capture.
public final class AreaCaptureView: NSView {

    weak var windowRef: AreaCaptureOverlayWindow?

    private let snapshot: ScreenSnapshot
    private let primaryScreenHeight: CGFloat
    private let loupeView = MagnifierLoupeView()

    // Selection State
    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var selectionRect: CGRect = .zero
    private var isDragging: Bool = false
    private var isSpacebarDown: Bool = false
    private var spacebarDragOffset: CGPoint = .zero

    // Hovered Window for Snapping
    private var hoveredWindowRect: CGRect?

    public init(snapshot: ScreenSnapshot, primaryScreenHeight: CGFloat) {
        self.snapshot = snapshot
        self.primaryScreenHeight = primaryScreenHeight
        super.init(frame: NSRect(origin: .zero, size: snapshot.frame.size))

        self.wantsLayer = true
        setupLoupe()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLoupe() {
        loupeView.sampleImage = snapshot.image
        addSubview(loupeView)
        loupeView.isHidden = false
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        let options: NSTrackingArea.Options = [.activeAlways, .mouseMoved, .cursorUpdate]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    // MARK: - Drawing

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // 1. Draw base frozen screen snapshot
        context.draw(snapshot.image, in: bounds)

        // 2. Draw 40% black dimming mask
        context.saveGState()
        context.setFillColor(CGColor(gray: 0.0, alpha: 0.40))

        if isDragging && !selectionRect.isEmpty {
            // Cut out the clear selection rect
            let maskPath = CGMutablePath()
            maskPath.addRect(bounds)
            maskPath.addRect(selectionRect)
            context.addPath(maskPath)
            context.clip(using: .evenOdd)
            context.fill(bounds)

            context.restoreGState()

            // 3. Draw crisp 1px selection border with accent line
            context.setStrokeColor(CGColor(red: 0.18, green: 0.46, blue: 1.0, alpha: 1.0))
            context.setLineWidth(1.5)
            context.stroke(selectionRect)
        } else if let windowRect = hoveredWindowRect {
            // Cut out hovered window
            let maskPath = CGMutablePath()
            maskPath.addRect(bounds)
            maskPath.addRect(windowRect)
            context.addPath(maskPath)
            context.clip(using: .evenOdd)
            context.fill(bounds)
            context.restoreGState()

            // Highlight window border
            context.setStrokeColor(CGColor(red: 0.18, green: 0.46, blue: 1.0, alpha: 0.9))
            context.setLineWidth(2.0)
            context.stroke(windowRect)
        } else {
            context.fill(bounds)
            context.restoreGState()
        }
    }

    // MARK: - Mouse Events

    public override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        updateLoupe(at: location)

        if !isDragging {
            // Check for hovered application window to enable snapping
            let globalPoint = event.window?.convertToScreen(NSRect(origin: event.locationInWindow, size: .zero)).origin ?? location
            let windowInfo = WindowDetector.shared.hitTestWindow(at: globalPoint, primaryScreenHeight: primaryScreenHeight)

            if let info = windowInfo {
                let localRect = DisplayCoordinateConverter.toLocalDisplayRect(globalRect: info.bounds, displayBounds: snapshot.frame)
                hoveredWindowRect = localRect
            } else {
                hoveredWindowRect = nil
            }
            needsDisplay = true
        }
    }

    public override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        startPoint = location
        currentPoint = location
        isDragging = true
        hoveredWindowRect = nil
        selectionRect = CGRect(origin: location, size: .zero)
        updateLoupe(at: location)
        needsDisplay = true
    }

    public override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let location = convert(event.locationInWindow, from: nil)

        if isSpacebarDown {
            // Reposition existing selection rectangle
            let dx = location.x - spacebarDragOffset.x
            let dy = location.y - spacebarDragOffset.y
            selectionRect.origin.x += dx
            selectionRect.origin.y += dy
            spacebarDragOffset = location
        } else {
            // Normal resize drag
            var rect = CGRect(
                x: min(start.x, location.x),
                y: min(start.y, location.y),
                width: abs(location.x - start.x),
                height: abs(location.y - start.y)
            )

            // Constrain 1:1 if Shift is pressed
            if event.modifierFlags.contains(.shift) {
                let side = max(rect.width, rect.height)
                rect.size = CGSize(width: side, height: side)
            }

            selectionRect = rect
        }

        currentPoint = location
        updateLoupe(at: location)
        needsDisplay = true
    }

    public override func mouseUp(with event: NSEvent) {
        isDragging = false

        let finalRect: CGRect
        if selectionRect.width > 2 && selectionRect.height > 2 {
            finalRect = selectionRect
        } else if let windowRect = hoveredWindowRect {
            finalRect = windowRect
        } else {
            // Clicked without dragging or window target - dismiss
            windowRef?.onCaptureCompleted?(nil)
            return
        }

        // Convert local display rect to physical pixels for cropping
        let cgY = snapshot.frame.height - (finalRect.origin.y + finalRect.size.height)
        let cgRect = CGRect(x: finalRect.origin.x, y: cgY, width: finalRect.size.width, height: finalRect.size.height)
        let pixelRect = DisplayCoordinateConverter.toPixelRect(pointRect: cgRect, scaleFactor: snapshot.scaleFactor)

        guard let croppedCG = snapshot.image.cropping(to: pixelRect) else {
            windowRef?.onCaptureCompleted?(nil)
            return
        }

        let image = NSImage(cgImage: croppedCG, size: finalRect.size)
        windowRef?.onCaptureCompleted?(image)
    }

    // MARK: - Key Events

    public override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            windowRef?.onCaptureCompleted?(nil)
            return
        }

        if event.keyCode == 49 { // Spacebar
            isSpacebarDown = true
            if let current = currentPoint {
                spacebarDragOffset = current
            }
            return
        }

        // Arrow keys nudge selection rect
        let nudgeAmount: CGFloat = event.modifierFlags.contains(.shift) ? 10.0 : 1.0
        switch event.keyCode {
        case 123: // Left
            selectionRect.origin.x -= nudgeAmount
        case 124: // Right
            selectionRect.origin.x += nudgeAmount
        case 125: // Down
            selectionRect.origin.y -= nudgeAmount
        case 126: // Up
            selectionRect.origin.y += nudgeAmount
        default:
            super.keyDown(with: event)
            return
        }
        needsDisplay = true
    }

    public override func keyUp(with event: NSEvent) {
        if event.keyCode == 49 { // Spacebar released
            isSpacebarDown = false
        } else {
            super.keyUp(with: event)
        }
    }

    // MARK: - Loupe Positioning

    private func updateLoupe(at point: CGPoint) {
        // Offset loupe slightly away from cursor
        var loupeOrigin = CGPoint(x: point.x + 24, y: point.y + 24)

        // Keep inside view bounds
        if loupeOrigin.x + loupeView.frame.width > bounds.width {
            loupeOrigin.x = point.x - loupeView.frame.width - 24
        }
        if loupeOrigin.y + loupeView.frame.height > bounds.height {
            loupeOrigin.y = point.y - loupeView.frame.height - 24
        }

        loupeView.frame.origin = loupeOrigin
        loupeView.selectionDimensions = selectionRect.size

        // Sample point in image coordinates (scaleFactor)
        let cgY = bounds.height - point.y
        loupeView.samplePoint = CGPoint(x: point.x * snapshot.scaleFactor, y: cgY * snapshot.scaleFactor)
    }
}
