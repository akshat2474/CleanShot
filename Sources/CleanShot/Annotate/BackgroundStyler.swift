import AppKit
import CoreImage

public enum BackgroundBackdrop: Sendable {
    case transparent
    case solid(color: NSColor)
    case gradient(start: NSColor, end: NSColor)
    case desktopWallpaper
}

public struct BackgroundStyleOptions: Sendable {
    public var backdrop: BackgroundBackdrop
    public var padding: CGFloat
    public var cornerRadius: CGFloat
    public var shadowRadius: CGFloat
    public var shadowOpacity: Float

    public init(
        backdrop: BackgroundBackdrop = .gradient(
            start: NSColor(red: 0.20, green: 0.45, blue: 1.0, alpha: 1.0),
            end: NSColor(red: 0.65, green: 0.25, blue: 0.95, alpha: 1.0)
        ),
        padding: CGFloat = 40.0,
        cornerRadius: CGFloat = 12.0,
        shadowRadius: CGFloat = 20.0,
        shadowOpacity: Float = 0.40
    ) {
        self.backdrop = backdrop
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.shadowOpacity = shadowOpacity
    }
}

/// Applies padding, gradients, wallpaper, shadows, and rounded corners to screenshots.
public final class BackgroundStyler {

    public static func apply(image: NSImage, options: BackgroundStyleOptions) -> NSImage {
        let totalWidth = image.size.width + (options.padding * 2)
        let totalHeight = image.size.height + (options.padding * 2)
        let targetSize = NSSize(width: totalWidth, height: totalHeight)

        let composite = NSImage(size: targetSize)
        composite.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            composite.unlockFocus()
            return image
        }

        let fullRect = CGRect(origin: .zero, size: targetSize)

        // 1. Draw Backdrop
        drawBackdrop(in: fullRect, backdrop: options.backdrop, context: context)

        // 2. Draw Shadow & Inner Image
        context.saveGState()

        if options.shadowRadius > 0 {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(CGFloat(options.shadowOpacity))
            shadow.shadowBlurRadius = options.shadowRadius
            shadow.shadowOffset = NSSize(width: 0, height: -6)
            shadow.set()
        }

        let imageRect = NSRect(
            x: options.padding,
            y: options.padding,
            width: image.size.width,
            height: image.size.height
        )

        if options.cornerRadius > 0 {
            let clipPath = NSBezierPath(roundedRect: imageRect, xRadius: options.cornerRadius, yRadius: options.cornerRadius)
            clipPath.addClip()
        }

        image.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1.0)

        context.restoreGState()
        composite.unlockFocus()

        return composite
    }

    private static func drawBackdrop(in rect: CGRect, backdrop: BackgroundBackdrop, context: CGContext) {
        switch backdrop {
        case .transparent:
            break
        case .solid(let color):
            context.setFillColor(color.cgColor)
            context.fill(rect)
        case .gradient(let start, let end):
            let colors = [start.cgColor, end.cgColor] as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) {
                context.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: rect.minX, y: rect.maxY),
                    end: CGPoint(x: rect.maxX, y: rect.minY),
                    options: []
                )
            }
        case .desktopWallpaper:
            if let screen = NSScreen.main,
               let wallpaperURL = NSWorkspace.shared.desktopImageURL(for: screen),
               let wallpaper = NSImage(contentsOf: wallpaperURL) {
                wallpaper.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
            } else {
                context.setFillColor(CGColor(gray: 0.15, alpha: 1.0))
                context.fill(rect)
            }
        }
    }
}
