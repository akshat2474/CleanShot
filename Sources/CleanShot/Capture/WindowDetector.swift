import AppKit
import CoreGraphics

/// Model representing an on-screen window.
public struct WindowInfo: Sendable, Identifiable {
    public let id: CGWindowID
    public let ownerName: String
    public let title: String
    public let bounds: CGRect
    public let layer: Int

    public init(id: CGWindowID, ownerName: String, title: String, bounds: CGRect, layer: Int) {
        self.id = id
        self.ownerName = ownerName
        self.title = title
        self.bounds = bounds
        self.layer = layer
    }
}

/// Service that enumerates on-screen windows and performs hit-testing for window selection.
@MainActor
public final class WindowDetector {
    public static let shared = WindowDetector()

    private init() {}

    /// Retrieves all visible application windows in front-to-back z-order.
    public func getVisibleWindows(primaryScreenHeight: CGFloat) -> [WindowInfo] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        var windows: [WindowInfo] = []

        for dict in infoList {
            guard let windowID = dict[kCGWindowNumber as String] as? CGWindowID,
                  let layer = dict[kCGWindowLayer as String] as? Int,
                  layer == 0, // Standard application windows only
                  let boundsDict = dict[kCGWindowBounds as String] as? [String: CGFloat],
                  let cgRect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else {
                continue
            }

            // Exclude empty or microscopic windows
            guard cgRect.width > 20 && cgRect.height > 20 else { continue }

            let ownerName = dict[kCGWindowOwnerName as String] as? String ?? ""
            let title = dict[kCGWindowName as String] as? String ?? ""

            // Exclude own CleanShot overlays
            if ownerName == "CleanShot" { continue }

            // Convert Core Graphics bounds to AppKit global coordinates
            let appKitRect = DisplayCoordinateConverter.toAppKit(rect: cgRect, primaryScreenHeight: primaryScreenHeight)

            let info = WindowInfo(
                id: windowID,
                ownerName: ownerName,
                title: title,
                bounds: appKitRect,
                layer: layer
            )
            windows.append(info)
        }

        return windows
    }

    /// Finds the topmost window containing the given global AppKit point.
    public func hitTestWindow(at globalPoint: CGPoint, primaryScreenHeight: CGFloat) -> WindowInfo? {
        let windows = getVisibleWindows(primaryScreenHeight: primaryScreenHeight)
        return windows.first { $0.bounds.contains(globalPoint) }
    }
}
