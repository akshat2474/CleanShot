import AppKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // 1. Setup Status Bar Menu
        MenuBarController.shared.setup()

        // 2. Wire Capture Coordinator Output to Quick Access Overlay
        CaptureCoordinator.shared.onCaptureResult = { image in
            QuickAccessOverlayController.shared.present(image: image)
        }

        // 3. Register Global Carbon Hotkeys
        registerGlobalHotKeys()

        print("[CleanShot] Initialized and listening for global shortcuts.")
    }

    private func registerGlobalHotKeys() {
        for action in CaptureAction.allCases {
            HotKeyManager.shared.register(
                id: action.rawValue,
                keyCode: action.defaultKeyCode,
                modifiers: action.defaultModifiers
            ) { [weak self] in
                self?.handleAction(action)
            }
        }
    }

    private func handleAction(_ action: CaptureAction) {
        switch action {
        case .captureArea:
            CaptureCoordinator.shared.startAreaCapture()
        case .captureWindow:
            CaptureCoordinator.shared.captureWindow()
        case .captureFullscreen:
            CaptureCoordinator.shared.captureFullscreen()
        case .capturePreviousArea:
            CaptureCoordinator.shared.capturePreviousArea()
        case .scrollingCapture:
            CaptureCoordinator.shared.startAreaCapture()
        case .selfTimer:
            CaptureCoordinator.shared.startSelfTimerCapture()
        case .recognizeText:
            CaptureCoordinator.shared.onCaptureResult = { image in
                Task {
                    await OCRService.shared.processImageAndCopyToClipboard(image)
                }
            }
            CaptureCoordinator.shared.startAreaCapture()
        case .recordScreen:
            Task {
                await ScreenRecordingEngine.shared.startRecording()
            }
        }
    }
}
