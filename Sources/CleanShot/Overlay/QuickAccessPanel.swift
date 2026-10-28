import AppKit

/// Floating HUD panel for the Quick Access Overlay.
@MainActor
public final class QuickAccessPanel: NSPanel {

    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false
    }

    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }
}

/// View controller managing the Quick Access thumbnail, countdown timer, drag-drop, and action buttons.
@MainActor
public final class QuickAccessViewController: NSViewController, NSDraggingSource {

    public var onSave: (() -> Void)?
    public var onCopy: (() -> Void)?
    public var onAnnotate: (() -> Void)?
    public var onPin: (() -> Void)?
    public var onClose: (() -> Void)?

    private let image: NSImage
    private var dismissTimer: Timer?
    private var remainingSeconds: Double = 6.0
    private let totalSeconds: Double = 6.0
    private var isHovered: Bool = false

    // UI Elements
    private let containerView = NSVisualEffectView()
    private let thumbnailImageView = NSImageView()
    private let timerProgressBar = NSProgressIndicator()
    private let actionsStack = NSStackView()

    public init(image: NSImage) {
        self.image = image
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func loadView() {
        let cardWidth: CGFloat = 220
        let cardHeight: CGFloat = 160
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: cardWidth, height: cardHeight))

        setupContainerView(width: cardWidth, height: cardHeight)
        setupThumbnail()
        setupProgressBar(width: cardWidth)
        setupActionButtons()
        startDismissTimer()
    }

    public override func viewDidAppear() {
        super.viewDidAppear()
        let trackingArea = NSTrackingArea(
            rect: view.bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        view.addTrackingArea(trackingArea)
    }

    // MARK: - Layout Setup

    private func setupContainerView(width: CGFloat, height: CGFloat) {
        containerView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        containerView.material = .hudWindow
        containerView.appearance = NSAppearance(named: .vibrantDark)
        containerView.state = .active
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 12.0
        containerView.layer?.masksToBounds = true
        containerView.layer?.borderWidth = 1.0
        containerView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.15).cgColor
        view.addSubview(containerView)
    }

    private func setupThumbnail() {
        thumbnailImageView.frame = NSRect(x: 12, y: 44, width: 196, height: 104)
        thumbnailImageView.image = image
        thumbnailImageView.imageScaling = .scaleProportionallyUpOrDown
        thumbnailImageView.wantsLayer = true
        thumbnailImageView.layer?.cornerRadius = 6.0
        thumbnailImageView.layer?.masksToBounds = true
        containerView.addSubview(thumbnailImageView)
    }

    private func setupProgressBar(width: CGFloat) {
        timerProgressBar.frame = NSRect(x: 0, y: 38, width: width, height: 2)
        timerProgressBar.isIndeterminate = false
        timerProgressBar.minValue = 0.0
        timerProgressBar.maxValue = totalSeconds
        timerProgressBar.doubleValue = totalSeconds
        containerView.addSubview(timerProgressBar)
    }

    private func setupActionButtons() {
        actionsStack.frame = NSRect(x: 8, y: 6, width: 204, height: 26)
        actionsStack.orientation = .horizontal
        actionsStack.distribution = .fillEqually
        actionsStack.spacing = 6

        let saveBtn = createActionButton(title: "Save", action: #selector(saveClicked))
        let copyBtn = createActionButton(title: "Copy", action: #selector(copyClicked))
        let annotateBtn = createActionButton(title: "Edit", action: #selector(annotateClicked))
        let pinBtn = createActionButton(title: "Pin", action: #selector(pinClicked))
        let closeBtn = createActionButton(title: "✕", action: #selector(closeClicked))

        actionsStack.addArrangedSubview(saveBtn)
        actionsStack.addArrangedSubview(copyBtn)
        actionsStack.addArrangedSubview(annotateBtn)
        actionsStack.addArrangedSubview(pinBtn)
        actionsStack.addArrangedSubview(closeBtn)

        containerView.addSubview(actionsStack)
    }

    private func createActionButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .inline
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.1).cgColor
        button.layer?.cornerRadius = 5.0
        button.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        button.contentTintColor = .white
        return button
    }

    // MARK: - Actions

    @objc private func saveClicked() {
        dismissTimer?.invalidate()
        onSave?()
    }

    @objc private func copyClicked() {
        dismissTimer?.invalidate()
        onCopy?()
    }

    @objc private func annotateClicked() {
        dismissTimer?.invalidate()
        onAnnotate?()
    }

    @objc private func pinClicked() {
        dismissTimer?.invalidate()
        onPin?()
    }

    @objc private func closeClicked() {
        dismissTimer?.invalidate()
        onClose?()
    }

    // MARK: - Timer

    private func startDismissTimer() {
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }

                guard !self.isHovered else { return }

                self.remainingSeconds -= 0.05
                self.timerProgressBar.doubleValue = max(0, self.remainingSeconds)

                if self.remainingSeconds <= 0 {
                    self.dismissTimer?.invalidate()
                    self.dismissTimer = nil
                    self.onClose?()
                }
            }
        }
    }

    public override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }

    public override func mouseExited(with event: NSEvent) {
        isHovered = false
    }

    // MARK: - Drag & Drop

    public override func mouseDragged(with event: NSEvent) {
        dismissTimer?.invalidate()

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("CleanShot-\(UUID().uuidString).png")
        try? pngData.write(to: tempURL)

        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setData(pngData, forType: .png)
        pasteboardItem.setString(tempURL.absoluteString, forType: .fileURL)

        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        draggingItem.setDraggingFrame(thumbnailImageView.bounds, contents: image)

        view.beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    public func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }
}
