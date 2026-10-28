import AppKit
@preconcurrency import AVFoundation

/// Floating circular picture-in-picture webcam bubble rendered during screen recording.
@MainActor
public final class WebcamOverlayPanel: NSPanel {

    private let captureSession = AVCaptureSession()
    private let cameraQueue = DispatchQueue(label: "io.cleanshot.camera")
    private var previewLayer: AVCaptureVideoPreviewLayer?

    public init(diameter: CGFloat = 160.0) {
        let initialRect = NSRect(x: 40, y: 40, width: diameter, height: diameter)

        super.init(
            contentRect: initialRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = true

        setupCamera(diameter: diameter)
    }

    private func setupCamera(diameter: CGFloat) {
        guard let contentView = contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = diameter / 2.0
        contentView.layer?.masksToBounds = true
        contentView.layer?.borderWidth = 3.0
        contentView.layer?.borderColor = NSColor.white.cgColor

        guard let videoDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoInput) else {
            return
        }

        captureSession.addInput(videoInput)

        let preview = AVCaptureVideoPreviewLayer(session: captureSession)
        preview.frame = contentView.bounds
        preview.videoGravity = .resizeAspectFill
        contentView.layer?.addSublayer(preview)
        self.previewLayer = preview
    }

    public func startCamera() {
        let session = captureSession
        cameraQueue.async {
            session.startRunning()
        }
        orderFront(nil)
    }

    public func stopCamera() {
        let session = captureSession
        cameraQueue.async {
            session.stopRunning()
        }
        orderOut(nil)
    }
}
