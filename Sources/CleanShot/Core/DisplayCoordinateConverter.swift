import AppKit

/// Utility for translating coordinates and frames between AppKit (bottom-left) and CoreGraphics (top-left) spaces.
public struct DisplayCoordinateConverter: Sendable {

    /// Converts an AppKit point to CoreGraphics display point.
    public static func toCoreGraphics(point: CGPoint, primaryScreenHeight: CGFloat) -> CGPoint {
        return CGPoint(x: point.x, y: primaryScreenHeight - point.y)
    }

    /// Converts an AppKit rectangle to CoreGraphics display rectangle.
    public static func toCoreGraphics(rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        let cgY = primaryScreenHeight - (rect.origin.y + rect.size.height)
        return CGRect(x: rect.origin.x, y: cgY, width: rect.size.width, height: rect.size.height)
    }

    /// Converts a CoreGraphics rectangle back to AppKit rectangle.
    public static func toAppKit(rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        let appKitY = primaryScreenHeight - (rect.origin.y + rect.size.height)
        return CGRect(x: rect.origin.x, y: appKitY, width: rect.size.width, height: rect.size.height)
    }

    /// Translates an absolute global screen rectangle into a local display rectangle (origin at display's top-left).
    public static func toLocalDisplayRect(globalRect: CGRect, displayBounds: CGRect) -> CGRect {
        let localX = globalRect.origin.x - displayBounds.origin.x
        let localY = globalRect.origin.y - displayBounds.origin.y
        return CGRect(x: localX, y: localY, width: globalRect.size.width, height: globalRect.size.height)
    }

    /// Scales a point-based rectangle to physical backing pixels.
    public static func toPixelRect(pointRect: CGRect, scaleFactor: CGFloat) -> CGRect {
        return CGRect(
            x: round(pointRect.origin.x * scaleFactor),
            y: round(pointRect.origin.y * scaleFactor),
            width: round(pointRect.size.width * scaleFactor),
            height: round(pointRect.size.height * scaleFactor)
        )
    }
}
