import AppKit
import CoreGraphics

/// Configuration options for capturing application windows.
public struct WindowCaptureOptions: Sendable {
    public var includeShadow: Bool
    public var padding: CGFloat
    public var cornerRadius: CGFloat
    public var customShadowRadius: CGFloat
    public var customShadowOpacity: Float

    public init(
        includeShadow: Bool = true,
        padding: CGFloat = 0,
        cornerRadius: CGFloat = 0,
        customShadowRadius: CGFloat = 16,
        customShadowOpacity: Float = 0.35
    ) {
        self.includeShadow = includeShadow
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.customShadowRadius = customShadowRadius
        self.customShadowOpacity = customShadowOpacity
    }
}

/// Captures isolated application windows with configurable drop shadows and styling.
@MainActor
public final class WindowCaptureService {
    public static let shared = WindowCaptureService()

    private init() {}

    /// Captures a specific window by its CGWindowID.
    public func captureWindow(windowID: CGWindowID, options: WindowCaptureOptions = WindowCaptureOptions()) -> NSImage? {
        let imageOptions: CGWindowImageOption = options.includeShadow ? [] : .boundsIgnoreFraming
        guard let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            imageOptions
        ) else {
            return nil
        }

        let baseImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))

        guard options.padding > 0 else {
            return baseImage
        }

        return applyPaddingAndStyling(to: baseImage, options: options)
    }

    // MARK: - Styling

    private func applyPaddingAndStyling(to image: NSImage, options: WindowCaptureOptions) -> NSImage {
        let totalWidth = image.size.width + (options.padding * 2)
        let totalHeight = image.size.height + (options.padding * 2)
        let targetSize = NSSize(width: totalWidth, height: totalHeight)

        let composite = NSImage(size: targetSize)
        composite.lockFocus()

        let context = NSGraphicsContext.current?.cgContext
        context?.saveGState()

        // Apply custom drop shadow if requested
        if options.customShadowRadius > 0 {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(CGFloat(options.customShadowOpacity))
            shadow.shadowBlurRadius = options.customShadowRadius
            shadow.shadowOffset = NSSize(width: 0, height: -4)
            shadow.set()
        }

        let imageRect = NSRect(
            x: options.padding,
            y: options.padding,
            width: image.size.width,
            height: image.size.height
        )

        // Draw image (with optional rounded corners)
        if options.cornerRadius > 0 {
            let clipPath = NSBezierPath(roundedRect: imageRect, xRadius: options.cornerRadius, yRadius: options.cornerRadius)
            clipPath.addClip()
        }

        image.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1.0)

        context?.restoreGState()
        composite.unlockFocus()

        return composite
    }
}
