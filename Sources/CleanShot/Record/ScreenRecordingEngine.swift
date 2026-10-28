import AppKit
import AVFoundation
import ScreenCaptureKit

/// Thread-safe sample buffer recorder for ScreenCaptureKit frames and audio packets.
private final class SampleBufferRecorder: @unchecked Sendable {
    var assetWriter: AVAssetWriter?
    var videoInput: AVAssetWriterInput?
    var audioInput: AVAssetWriterInput?
    var recordingStartTime: CMTime = .invalid
    private let lock = NSLock()

    func append(_ sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        lock.lock()
        defer { lock.unlock() }

        guard let writer = assetWriter, writer.status == .writing else { return }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if recordingStartTime == .invalid {
            recordingStartTime = timestamp
            writer.startSession(atSourceTime: timestamp)
        }

        switch type {
        case .screen:
            if videoInput?.isReadyForMoreMediaData == true {
                videoInput?.append(sampleBuffer)
            }
        case .audio, .microphone:
            if audioInput?.isReadyForMoreMediaData == true {
                audioInput?.append(sampleBuffer)
            }
        @unknown default:
            break
        }
    }

    func finish(completion: @escaping @Sendable (URL?) -> Void) {
        lock.lock()
        defer { lock.unlock() }

        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        let url = assetWriter?.outputURL
        assetWriter?.finishWriting {
            completion(url)
        }
    }
}

/// Screen recording coordinator utilizing ScreenCaptureKit for hardware-accelerated video and system audio loopback.
@MainActor
public final class ScreenRecordingEngine: NSObject, SCStreamOutput, @unchecked Sendable {
    public static let shared = ScreenRecordingEngine()

    private var stream: SCStream?
    private let recorder = SampleBufferRecorder()
    private var isRecording: Bool = false

    private var recordingHUD: NSPanel?
    private var hudTimer: Timer?
    private var elapsedSeconds: Int = 0
    private var timeLabel: NSTextField?
    private var webcamOverlay: WebcamOverlayPanel?

    public var onRecordingFinished: ((URL) -> Void)?

    private override init() {
        super.init()
    }

    // MARK: - Start Recording

    public func startRecording(area: CGRect? = nil, includeWebcam: Bool = false) async {
        guard !isRecording else { return }
        guard PermissionsManager.shared.requestScreenCaptureAccess() else {
            PermissionsManager.shared.showScreenCapturePermissionAlert()
            return
        }

        guard let content = try? await SCShareableContent.current else { return }
        guard let display = content.displays.first else { return }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = display.width
        config.height = display.height
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60) // 60 FPS
        config.queueDepth = 5
        config.capturesAudio = true
        config.sampleRate = 48000
        config.channelCount = 2

        if let area = area {
            config.sourceRect = area
            config.width = Int(area.width * 2)
            config.height = Int(area.height * 2)
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("CleanShot-\(UUID().uuidString).mp4")
        guard setupAssetWriter(outputURL: tempURL, width: config.width, height: config.height) else { return }

        do {
            let scStream = SCStream(filter: filter, configuration: config, delegate: nil)
            try scStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: DispatchQueue(label: "io.cleanshot.video"))
            try scStream.addStreamOutput(self, type: .audio, sampleHandlerQueue: DispatchQueue(label: "io.cleanshot.audio"))
            try await scStream.startCapture()

            self.stream = scStream
            self.isRecording = true
            self.elapsedSeconds = 0

            showRecordingHUD()

            if includeWebcam {
                let webcam = WebcamOverlayPanel()
                webcam.startCamera()
                self.webcamOverlay = webcam
            }
        } catch {
            print("[ScreenRecordingEngine] Failed to start capture: \(error)")
        }
    }

    // MARK: - Stop Recording

    public func stopRecording() async {
        guard isRecording, let stream = stream else { return }

        try? await stream.stopCapture()
        self.stream = nil
        self.isRecording = false

        hideRecordingHUD()
        webcamOverlay?.stopCamera()
        webcamOverlay = nil

        recorder.finish { [weak self] outputURL in
            Task { @MainActor in
                if let outputURL = outputURL {
                    self?.onRecordingFinished?(outputURL)
                }
            }
        }
    }

    // MARK: - Asset Writer Setup

    private func setupAssetWriter(outputURL: URL, width: Int, height: Int) -> Bool {
        try? FileManager.default.removeItem(at: outputURL)

        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else { return false }

        // Video Settings
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]
        let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        vInput.expectsMediaDataInRealTime = true
        guard writer.canAdd(vInput) else { return false }
        writer.add(vInput)

        // Audio Settings
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128000
        ]
        let aInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        aInput.expectsMediaDataInRealTime = true
        if writer.canAdd(aInput) {
            writer.add(aInput)
        }

        writer.startWriting()

        recorder.assetWriter = writer
        recorder.videoInput = vInput
        recorder.audioInput = aInput
        recorder.recordingStartTime = .invalid
        return true
    }

    // MARK: - SCStreamOutput

    public nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid else { return }
        recorder.append(sampleBuffer, of: type)
    }

    // MARK: - Floating Recording HUD

    private func showRecordingHUD() {
        let hudWidth: CGFloat = 180
        let hudHeight: CGFloat = 36

        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let rect = NSRect(
            x: screen.visibleFrame.midX - (hudWidth / 2),
            y: screen.visibleFrame.minY + 20,
            width: hudWidth,
            height: hudHeight
        )

        let panel = NSPanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        let effectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: rect.size))
        effectView.material = .hudWindow
        effectView.appearance = NSAppearance(named: .vibrantDark)
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 18.0
        effectView.layer?.masksToBounds = true
        panel.contentView = effectView

        // Red Recording Dot
        let dot = NSView(frame: NSRect(x: 14, y: 13, width: 10, height: 10))
        dot.wantsLayer = true
        dot.layer?.backgroundColor = NSColor.systemRed.cgColor
        dot.layer?.cornerRadius = 5.0
        effectView.addSubview(dot)

        // Time Counter
        let label = NSTextField(frame: NSRect(x: 32, y: 8, width: 70, height: 20))
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.textColor = .white
        label.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        label.stringValue = "00:00"
        effectView.addSubview(label)
        self.timeLabel = label

        // Stop Button
        let stopButton = NSButton(title: "Stop", target: self, action: #selector(stopButtonClicked))
        stopButton.frame = NSRect(x: 108, y: 5, width: 60, height: 26)
        stopButton.bezelStyle = .rounded
        stopButton.contentTintColor = .systemRed
        effectView.addSubview(stopButton)

        panel.orderFront(nil)
        self.recordingHUD = panel

        hudTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.elapsedSeconds += 1
                let minutes = self.elapsedSeconds / 60
                let seconds = self.elapsedSeconds % 60
                self.timeLabel?.stringValue = String(format: "%02d:%02d", minutes, seconds)
            }
        }
    }

    private func hideRecordingHUD() {
        hudTimer?.invalidate()
        hudTimer = nil
        recordingHUD?.orderOut(nil)
        recordingHUD = nil
    }

    @objc private func stopButtonClicked() {
        Task {
            await stopRecording()
        }
    }
}
