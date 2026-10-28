import AppKit
import AVFoundation

/// Coordinates and audits system permissions required for screen capture, recording, and automation.
@MainActor
public final class PermissionsManager {
    public static let shared = PermissionsManager()

    private init() {}

    // MARK: - Status Checks

    public var isScreenCaptureGranted: Bool {
        CGPreflightScreenCaptureAccess()
    }

    public var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    public var isMicrophoneGranted: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    public var isCameraGranted: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    // MARK: - Requests

    public func requestScreenCaptureAccess() -> Bool {
        if isScreenCaptureGranted { return true }

        // Practical capability probe: can we actually capture a screen frame?
        // On macOS Sequoia and ad-hoc builds, CGPreflightScreenCaptureAccess may return false
        // even when screen recording is granted until full restart, but frame capture already succeeds.
        if let screen = NSScreen.main ?? NSScreen.screens.first,
           let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
           let testImage = CGDisplayCreateImage(displayID),
           testImage.width > 0 {
            return true
        }

        return CGRequestScreenCaptureAccess()
    }

    public func requestAccessibilityAccess() {
        if isAccessibilityGranted { return }
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    public func requestMicrophoneAccess() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        guard status == .notDetermined else {
            return status == .authorized
        }
        return await AVCaptureDevice.requestAccess(for: .audio)
    }

    public func requestCameraAccess() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        guard status == .notDetermined else {
            return status == .authorized
        }
        return await AVCaptureDevice.requestAccess(for: .video)
    }

    // MARK: - Educational Alerts & Settings Deep Links

    public func showScreenCapturePermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "CleanShot requires Screen Recording permission to capture screens and windows.\n\nIf you have already toggled CleanShot in System Settings, macOS requires quitting and restarting CleanShot for the new permission to apply."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Restart CleanShot")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openSystemSettingsScreenRecording()
        } else if response == .alertSecondButtonReturn {
            relaunchApp()
        }
    }

    public func relaunchApp() {
        let bundleURL = Bundle.main.bundleURL
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", bundleURL.path]
        try? process.run()
        NSApp.terminate(nil)
    }

    public func openSystemSettingsScreenRecording() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
    }

    public func openSystemSettingsAccessibility() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}
