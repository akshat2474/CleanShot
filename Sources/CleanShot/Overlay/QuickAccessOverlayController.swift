import AppKit

/// Coordinates the presentation, positioning, and lifecycle of the Quick Access Overlay.
@MainActor
public final class QuickAccessOverlayController {
    public static let shared = QuickAccessOverlayController()

    private var activePanel: QuickAccessPanel?

    private init() {}

    public func present(image: NSImage) {
        dismiss()

        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let cardWidth: CGFloat = 220
        let cardHeight: CGFloat = 160
        let margin: CGFloat = 24

        // Position at bottom-right corner of screen
        let originX = screen.visibleFrame.maxX - cardWidth - margin
        let originY = screen.visibleFrame.minY + margin
        let rect = NSRect(x: originX, y: originY, width: cardWidth, height: cardHeight)

        let panel = QuickAccessPanel(contentRect: rect)
        let viewController = QuickAccessViewController(image: image)

        viewController.onSave = { [weak self] in
            self?.saveImageToDisk(image)
            self?.dismiss()
        }

        viewController.onCopy = { [weak self] in
            self?.copyImageToClipboard(image)
            self?.dismiss()
        }

        viewController.onAnnotate = { [weak self] in
            self?.dismiss()
            AnnotationEditorCoordinator.shared.openEditor(with: image)
        }

        viewController.onPin = { [weak self] in
            self?.dismiss()
            PinnedScreenshotController.shared.pin(image: image)
        }

        viewController.onClose = { [weak self] in
            self?.dismiss()
        }

        panel.contentViewController = viewController
        panel.orderFront(nil)
        activePanel = panel
    }

    public func dismiss() {
        activePanel?.orderOut(nil)
        activePanel = nil
    }

    // MARK: - Actions

    public func copyImageToClipboard(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }

    public func saveImageToDisk(_ image: NSImage) {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return
        }

        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let dateString = formatter.string(from: Date())
        let filename = "CleanShot \(dateString).png"
        let fileURL = desktopURL.appendingPathComponent(filename)

        try? pngData.write(to: fileURL)
    }
}
