import AppKit

/// Floating pinned reference window that stays always on top with zoom, opacity, and lock controls.
@MainActor
public final class PinnedScreenshotWindow: NSPanel {

    private let imageView = NSImageView()
    private var zoomScale: CGFloat = 1.0
    private var isLocked: Bool = false

    public init(image: NSImage, origin: CGPoint) {
        let defaultSize = NSSize(
            width: min(image.size.width, 600),
            height: min(image.size.height, 450)
        )
        let rect = NSRect(origin: origin, size: defaultSize)

        super.init(
            contentRect: rect,
            styleMask: [.borderless, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = true

        setupImageView(image: image)
    }

    public override var canBecomeKey: Bool { true }

    private func setupImageView(image: NSImage) {
        imageView.frame = contentView?.bounds ?? .zero
        imageView.autoresizingMask = [.width, .height]
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 8.0
        imageView.layer?.masksToBounds = true
        contentView?.addSubview(imageView)
    }

    // MARK: - Controls

    public func adjustOpacity(delta: CGFloat) {
        let newAlpha = max(0.1, min(1.0, alphaValue + delta))
        alphaValue = newAlpha
    }

    public func adjustZoom(multiplier: CGFloat) {
        zoomScale = max(0.2, min(5.0, zoomScale * multiplier))
        let newSize = NSSize(width: frame.width * multiplier, height: frame.height * multiplier)
        setFrame(NSRect(origin: frame.origin, size: newSize), display: true, animate: false)
    }

    public func toggleLockMode() {
        isLocked.toggle()
        ignoresMouseEvents = isLocked
    }

    // MARK: - Key Events

    public override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc
            orderOut(nil)
            return
        }

        // Cmd + ] (increase opacity) / Cmd + [ (decrease opacity)
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "]":
                adjustOpacity(delta: 0.1)
                return
            case "[":
                adjustOpacity(delta: -0.1)
                return
            case "+", "=":
                adjustZoom(multiplier: 1.1)
                return
            case "-":
                adjustZoom(multiplier: 0.9)
                return
            case "l":
                toggleLockMode()
                return
            default:
                break
            }
        }

        super.keyDown(with: event)
    }
}

/// Controller managing all active pinned screenshots.
@MainActor
public final class PinnedScreenshotController {
    public static let shared = PinnedScreenshotController()

    private var activePins: [PinnedScreenshotWindow] = []

    private init() {}

    public func pin(image: NSImage) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let origin = CGPoint(
            x: screen.visibleFrame.midX - 200 + CGFloat(activePins.count * 20),
            y: screen.visibleFrame.midY - 150 - CGFloat(activePins.count * 20)
        )

        let pinWindow = PinnedScreenshotWindow(image: image, origin: origin)
        pinWindow.orderFront(nil)
        activePins.append(pinWindow)
    }

    public func closeAllPins() {
        for pin in activePins {
            pin.orderOut(nil)
        }
        activePins.removeAll()
    }
}
