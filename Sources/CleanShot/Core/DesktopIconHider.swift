import AppKit

/// Hides desktop icons seamlessly with zero latency by overlaying wallpaper windows at the desktop icon layer.
@MainActor
public final class DesktopIconHider {
    public static let shared = DesktopIconHider()

    private var overlayWindows: [NSWindow] = []
    public private(set) var areIconsHidden: Bool = false

    private init() {}

    // MARK: - Toggle

    public func toggle() {
        if areIconsHidden {
            showIcons()
        } else {
            hideIcons()
        }
    }

    public func hideIcons() {
        guard !areIconsHidden else { return }

        for screen in NSScreen.screens {
            guard let window = createWallpaperWindow(for: screen) else { continue }
            window.orderFront(nil)
            overlayWindows.append(window)
        }

        areIconsHidden = true
    }

    public func showIcons() {
        guard areIconsHidden else { return }

        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()

        areIconsHidden = false
    }

    // MARK: - Window Creation

    private func createWallpaperWindow(for screen: NSScreen) -> NSWindow? {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isOpaque = true
        window.hasShadow = false

        guard let wallpaperURL = NSWorkspace.shared.desktopImageURL(for: screen),
              let wallpaperImage = NSImage(contentsOf: wallpaperURL) else {
            return nil
        }

        let imageView = NSImageView(frame: CGRect(origin: .zero, size: screen.frame.size))
        imageView.image = wallpaperImage
        imageView.imageScaling = .scaleAxesIndependently

        window.contentView = imageView
        return window
    }
}
