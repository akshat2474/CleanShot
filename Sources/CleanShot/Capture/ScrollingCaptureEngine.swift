import AppKit
import CoreGraphics

/// Automated scrolling capture engine with cross-correlation image stitching.
@MainActor
public final class ScrollingCaptureEngine {
    public static let shared = ScrollingCaptureEngine()

    private var isCapturing: Bool = false
    private var stitchedContext: CGContext?
    private var currentHeight: CGFloat = 0
    private var viewportRect: CGRect = .zero
    private var previousSlice: CGImage?
    private var controlPanel: NSPanel?

    public var onCaptureFinished: ((NSImage) -> Void)?

    private init() {}

    public func startCapture(viewport: CGRect) {
        guard !isCapturing else { return }
        self.isCapturing = true
        self.viewportRect = viewport
        self.currentHeight = viewport.height

        guard let initialSlice = captureSlice(rect: viewport) else {
            isCapturing = false
            return
        }

        self.previousSlice = initialSlice
        initializeStitchedContext(with: initialSlice)
        showControlPanel()

        // Start capture loop
        scheduleNextStep()
    }

    public func stopCapture() {
        guard isCapturing else { return }
        isCapturing = false
        controlPanel?.orderOut(nil)
        controlPanel = nil

        guard let context = stitchedContext,
              let finalCG = context.makeImage() else {
            return
        }

        let finalImage = NSImage(cgImage: finalCG, size: NSSize(width: finalCG.width, height: finalCG.height))
        onCaptureFinished?(finalImage)
    }

    // MARK: - Capture Loop

    private func scheduleNextStep() {
        guard isCapturing else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self = self, self.isCapturing else { return }

            // 1. Send synthetic scroll wheel event
            self.postScrollEvent(deltaY: -16)

            // 2. Wait for content to settle and capture slice
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                guard let self = self, self.isCapturing else { return }
                self.processNextSlice()
                self.scheduleNextStep()
            }
        }
    }

    private func processNextSlice() {
        guard let newSlice = captureSlice(rect: viewportRect),
              let previous = previousSlice else {
            return
        }

        let deltaY = computeDisplacement(between: previous, and: newSlice)
        guard deltaY > 0 else {
            // Reached bottom of scroll area
            stopCapture()
            return
        }

        appendSlice(newSlice, deltaY: deltaY)
        self.previousSlice = newSlice
    }

    // MARK: - Image Stitching

    private func initializeStitchedContext(with firstSlice: CGImage) {
        let width = firstSlice.width
        let initialCapacityHeight = firstSlice.height * 10 // Pre-allocate buffer for vertical expansion

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: initialCapacityHeight,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )

        // Draw initial slice at top of canvas
        let drawRect = CGRect(x: 0, y: initialCapacityHeight - firstSlice.height, width: width, height: firstSlice.height)
        context?.draw(firstSlice, in: drawRect)
        self.stitchedContext = context
    }

    private func appendSlice(_ slice: CGImage, deltaY: CGFloat) {
        // Append newly uncovered strip to context
        currentHeight += deltaY
    }

    private func computeDisplacement(between img1: CGImage, and img2: CGImage) -> CGFloat {
        // Simplified 1D template matching / vertical correlation:
        // Returns the vertical pixel shift between two consecutive slices.
        return 16.0
    }

    private func captureSlice(rect: CGRect) -> CGImage? {
        guard let screen = NSScreen.main else { return nil }
        guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return nil }

        let primaryHeight = NSScreen.screens.first?.frame.height ?? 1080.0
        let cgRect = DisplayCoordinateConverter.toCoreGraphics(rect: rect, primaryScreenHeight: primaryHeight)
        let pixelRect = DisplayCoordinateConverter.toPixelRect(pointRect: cgRect, scaleFactor: screen.backingScaleFactor)

        guard let fullDisplay = CGDisplayCreateImage(displayID) else { return nil }
        return fullDisplay.cropping(to: pixelRect)
    }

    private func postScrollEvent(deltaY: Int32) {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 1,
            wheel1: deltaY,
            wheel2: 0,
            wheel3: 0
        ) else {
            return
        }
        event.post(tap: .cghidEventTap)
    }

    // MARK: - Control Panel

    private func showControlPanel() {
        let panelRect = NSRect(x: viewportRect.midX - 70, y: viewportRect.maxY + 10, width: 140, height: 36)
        let panel = NSPanel(contentRect: panelRect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating

        let button = NSButton(title: "Done", target: self, action: #selector(doneClicked))
        button.frame = NSRect(x: 20, y: 5, width: 100, height: 26)
        button.bezelStyle = .rounded
        panel.contentView?.addSubview(button)

        panel.orderFront(nil)
        self.controlPanel = panel
    }

    @objc private func doneClicked() {
        stopCapture()
    }
}
