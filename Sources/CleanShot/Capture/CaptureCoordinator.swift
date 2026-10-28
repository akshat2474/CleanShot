import AppKit

/// Central coordinator that launches capture modes and directs results to the Quick Access Overlay.
@MainActor
public final class CaptureCoordinator {
    public static let shared = CaptureCoordinator()

    private var activeOverlayWindows: [AreaCaptureOverlayWindow] = []
    private var lastCapturedRect: CGRect?
    private var lastCapturedScreen: NSScreen?

    public var onCaptureResult: ((NSImage) -> Void)?

    private init() {}

    // MARK: - Capture Area

    public func startAreaCapture() {
        guard PermissionsManager.shared.requestScreenCaptureAccess() else {
            PermissionsManager.shared.showScreenCapturePermissionAlert()
            return
        }

        let snapshots = FreezeScreenService.shared.captureAllScreens()
        guard !snapshots.isEmpty else { return }

        let primaryHeight = NSScreen.screens.first?.frame.height ?? 1080.0
        dismissActiveOverlays()

        for snapshot in snapshots {
            let window = AreaCaptureOverlayWindow(snapshot: snapshot, primaryScreenHeight: primaryHeight)
            window.onCaptureCompleted = { [weak self] image in
                self?.dismissActiveOverlays()
                guard let image = image else { return }
                self?.handleCapturedImage(image)
            }
            window.orderFront(nil)
            activeOverlayWindows.append(window)
        }
    }

    // MARK: - Capture Fullscreen

    public func captureFullscreen() {
        guard PermissionsManager.shared.requestScreenCaptureAccess() else {
            PermissionsManager.shared.showScreenCapturePermissionAlert()
            return
        }

        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
              let cgImage = CGDisplayCreateImage(displayID) else {
            return
        }

        let image = NSImage(cgImage: cgImage, size: screen.frame.size)
        handleCapturedImage(image)
    }

    // MARK: - Capture Window

    public func captureWindow(windowID: CGWindowID? = nil) {
        guard PermissionsManager.shared.requestScreenCaptureAccess() else {
            PermissionsManager.shared.showScreenCapturePermissionAlert()
            return
        }

        if let id = windowID {
            if let image = WindowCaptureService.shared.captureWindow(windowID: id) {
                handleCapturedImage(image)
            }
            return
        }

        // If no ID provided, trigger interactive window selection or area capture with window snapping
        startAreaCapture()
    }

    // MARK: - Capture Previous Area

    public func capturePreviousArea() {
        guard let rect = lastCapturedRect, let screen = lastCapturedScreen else {
            startAreaCapture()
            return
        }

        let snapshots = FreezeScreenService.shared.captureAllScreens()
        guard let match = snapshots.first(where: { $0.screen == screen }) else {
            startAreaCapture()
            return
        }

        let primaryHeight = NSScreen.screens.first?.frame.height ?? 1080.0
        guard let cropped = FreezeScreenService.shared.crop(snapshot: match, globalRect: rect, primaryScreenHeight: primaryHeight) else {
            startAreaCapture()
            return
        }

        let image = NSImage(cgImage: cropped, size: rect.size)
        handleCapturedImage(image)
    }

    // MARK: - Self Timer

    public func startSelfTimerCapture(delaySeconds: Int = 5) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delaySeconds)) { [weak self] in
            NSSound.beep()
            self?.startAreaCapture()
        }
    }

    // MARK: - Helper Handlers

    private func handleCapturedImage(_ image: NSImage) {
        onCaptureResult?(image)
    }

    private func dismissActiveOverlays() {
        for window in activeOverlayWindows {
            window.orderOut(nil)
        }
        activeOverlayWindows.removeAll()
    }
}
