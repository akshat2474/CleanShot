import AppKit

/// Coordinates the status item in the macOS menu bar and its dropdown menu.
@MainActor
public final class MenuBarController: NSObject, NSMenuDelegate {
    public static let shared = MenuBarController()

    private var statusItem: NSStatusItem?
    private let menu = NSMenu()

    private override init() {
        super.init()
    }

    public func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            if let image = NSImage(systemSymbolName: "camera.aperture", accessibilityDescription: "CleanShot") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "📸"
            }
        }

        buildMenu()
        statusItem?.menu = menu
        menu.delegate = self
    }

    private func buildMenu() {
        menu.removeAllItems()

        // Capture Options
        addMenuItem(title: "Capture Area", shortcut: "4", modifiers: [.command, .shift], action: #selector(captureAreaClicked))
        addMenuItem(title: "Capture Window", shortcut: "5", modifiers: [.command, .shift], action: #selector(captureWindowClicked))
        addMenuItem(title: "Capture Fullscreen", shortcut: "3", modifiers: [.command, .shift], action: #selector(captureFullscreenClicked))
        addMenuItem(title: "Capture Previous Area", shortcut: "6", modifiers: [.command, .shift], action: #selector(capturePreviousAreaClicked))
        addMenuItem(title: "Scrolling Capture", shortcut: "7", modifiers: [.command, .shift], action: #selector(scrollingCaptureClicked))
        addMenuItem(title: "Self-Timer Capture", shortcut: "8", modifiers: [.command, .shift], action: #selector(selfTimerClicked))
        addMenuItem(title: "Recognize Text (OCR)", shortcut: "2", modifiers: [.command, .shift], action: #selector(ocrClicked))
        addMenuItem(title: "Record Screen", shortcut: "9", modifiers: [.command, .shift], action: #selector(recordScreenClicked))

        menu.addItem(NSMenuItem.separator())

        // Desktop Utilities
        let desktopItem = NSMenuItem(title: "Hide Desktop Icons", action: #selector(toggleDesktopIconsClicked), keyEquivalent: "")
        desktopItem.target = self
        menu.addItem(desktopItem)

        let closePinsItem = NSMenuItem(title: "Close Pinned Screenshots", action: #selector(closePinsClicked), keyEquivalent: "")
        closePinsItem.target = self
        menu.addItem(closePinsItem)

        menu.addItem(NSMenuItem.separator())

        // System items
        let quitItem = NSMenuItem(title: "Quit CleanShot", action: #selector(quitClicked), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func addMenuItem(title: String, shortcut: String, modifiers: NSEvent.ModifierFlags, action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: shortcut)
        item.keyEquivalentModifierMask = modifiers
        item.target = self
        menu.addItem(item)
    }

    // MARK: - Menu Actions

    @objc private func captureAreaClicked() {
        CaptureCoordinator.shared.startAreaCapture()
    }

    @objc private func captureWindowClicked() {
        CaptureCoordinator.shared.captureWindow()
    }

    @objc private func captureFullscreenClicked() {
        CaptureCoordinator.shared.captureFullscreen()
    }

    @objc private func capturePreviousAreaClicked() {
        CaptureCoordinator.shared.capturePreviousArea()
    }

    @objc private func scrollingCaptureClicked() {
        CaptureCoordinator.shared.startAreaCapture()
    }

    @objc private func selfTimerClicked() {
        CaptureCoordinator.shared.startSelfTimerCapture()
    }

    @objc private func ocrClicked() {
        CaptureCoordinator.shared.onCaptureResult = { image in
            Task {
                await OCRService.shared.processImageAndCopyToClipboard(image)
            }
        }
        CaptureCoordinator.shared.startAreaCapture()
    }

    @objc private func recordScreenClicked() {
        Task {
            await ScreenRecordingEngine.shared.startRecording()
        }
    }

    @objc private func toggleDesktopIconsClicked(sender: NSMenuItem) {
        DesktopIconHider.shared.toggle()
        sender.title = DesktopIconHider.shared.areIconsHidden ? "Show Desktop Icons" : "Hide Desktop Icons"
    }

    @objc private func closePinsClicked() {
        PinnedScreenshotController.shared.closeAllPins()
    }

    @objc private func quitClicked() {
        NSApp.terminate(nil)
    }
}
