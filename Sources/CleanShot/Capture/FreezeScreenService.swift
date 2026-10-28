import AppKit
import CoreGraphics

/// Snapshot of a display screen captured at a specific instant.
public struct ScreenSnapshot: @unchecked Sendable {
    public let screen: NSScreen
    public let image: CGImage
    public let frame: CGRect
    public let scaleFactor: CGFloat

    public init(screen: NSScreen, image: CGImage, frame: CGRect, scaleFactor: CGFloat) {
        self.screen = screen
        self.image = image
        self.frame = frame
        self.scaleFactor = scaleFactor
    }
}

/// Instant screen buffer snapshotter used for freeze screen and area capture backgrounds.
@MainActor
public final class FreezeScreenService {
    public static let shared = FreezeScreenService()

    private init() {}

    /// Captures all active displays simultaneously into static snapshots.
    public func captureAllScreens() -> [ScreenSnapshot] {
        var snapshots: [ScreenSnapshot] = []

        for screen in NSScreen.screens {
            guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                continue
            }

            guard let cgImage = CGDisplayCreateImage(displayID) else {
                continue
            }

            let snapshot = ScreenSnapshot(
                screen: screen,
                image: cgImage,
                frame: screen.frame,
                scaleFactor: screen.backingScaleFactor
            )
            snapshots.append(snapshot)
        }

        return snapshots
    }

    /// Crops a region from a screen snapshot based on global AppKit coordinates.
    public func crop(snapshot: ScreenSnapshot, globalRect: CGRect, primaryScreenHeight: CGFloat) -> CGImage? {
        // Convert global AppKit rect to display-local coordinates
        let localRect = DisplayCoordinateConverter.toLocalDisplayRect(
            globalRect: globalRect,
            displayBounds: snapshot.frame
        )

        // Convert to Core Graphics coordinate space (origin top-left)
        let cgY = snapshot.frame.height - (localRect.origin.y + localRect.size.height)
        let cgLocalRect = CGRect(
            x: localRect.origin.x,
            y: cgY,
            width: localRect.size.width,
            height: localRect.size.height
        )

        // Scale to backing pixels
        let pixelRect = DisplayCoordinateConverter.toPixelRect(
            pointRect: cgLocalRect,
            scaleFactor: snapshot.scaleFactor
        )

        return snapshot.image.cropping(to: pixelRect)
    }
}
