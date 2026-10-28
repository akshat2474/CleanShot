import AppKit

/// Main window and controller for the built-in Annotation and Background editor.
@MainActor
public final class AnnotationEditorWindow: NSWindow {

    private let canvasView: CanvasView
    private let scrollView = NSScrollView()
    private var isBackgroundApplied: Bool = false

    public init(image: NSImage) {
        self.canvasView = CanvasView(baseImage: image)

        let initialSize = NSSize(
            width: min(max(image.size.width + 100, 750), 1200),
            height: min(max(image.size.height + 120, 550), 900)
        )

        super.init(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        self.title = "CleanShot Annotation Editor"
        self.center()
        self.setFrameAutosaveName("CleanShotAnnotationEditor")
        self.isReleasedWhenClosed = false

        setupUI()
    }

    private func setupUI() {
        guard let contentView = contentView else { return }

        // 1. Toolbar Bar at Top
        let toolbarView = NSView(frame: NSRect(x: 0, y: contentView.bounds.height - 44, width: contentView.bounds.width, height: 44))
        toolbarView.autoresizingMask = [.width, .minYMargin]
        toolbarView.wantsLayer = true
        toolbarView.layer?.backgroundColor = NSColor(white: 0.15, alpha: 1.0).cgColor
        contentView.addSubview(toolbarView)

        setupToolButtons(in: toolbarView)
        setupActionButtons(in: toolbarView)

        // 2. Central Scrollable Canvas Area
        scrollView.frame = NSRect(x: 0, y: 0, width: contentView.bounds.width, height: contentView.bounds.height - 44)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.2
        scrollView.maxMagnification = 4.0
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor(white: 0.1, alpha: 1.0) // Dark matte canvas

        // Centered clip view wrapper
        let canvasContainer = NSView(frame: NSRect(origin: .zero, size: canvasView.bounds.size))
        canvasContainer.addSubview(canvasView)
        scrollView.documentView = canvasContainer

        contentView.addSubview(scrollView)
    }

    private func setupToolButtons(in toolbar: NSView) {
        let toolsStack = NSStackView(frame: NSRect(x: 16, y: 8, width: 360, height: 28))
        toolsStack.orientation = .horizontal
        toolsStack.spacing = 8

        let arrowBtn = createButton(title: "Arrow", action: #selector(arrowToolSelected))
        let rectBtn = createButton(title: "Rect", action: #selector(rectToolSelected))
        let roundRectBtn = createButton(title: "Round", action: #selector(roundRectToolSelected))
        let ellipseBtn = createButton(title: "Circle", action: #selector(ellipseToolSelected))
        let counterBtn = createButton(title: "1 2 3", action: #selector(counterToolSelected))
        let bgBtn = createButton(title: "Backdrop", action: #selector(toggleBackdrop))

        toolsStack.addArrangedSubview(arrowBtn)
        toolsStack.addArrangedSubview(rectBtn)
        toolsStack.addArrangedSubview(roundRectBtn)
        toolsStack.addArrangedSubview(ellipseBtn)
        toolsStack.addArrangedSubview(counterBtn)
        toolsStack.addArrangedSubview(bgBtn)

        toolbar.addSubview(toolsStack)
    }

    private func setupActionButtons(in toolbar: NSView) {
        let actionsStack = NSStackView(frame: NSRect(x: toolbar.bounds.width - 210, y: 8, width: 194, height: 28))
        actionsStack.autoresizingMask = [.minXMargin]
        actionsStack.orientation = .horizontal
        actionsStack.spacing = 8

        let copyBtn = createButton(title: "Copy", action: #selector(copyAndClose))
        let saveBtn = createButton(title: "Save", action: #selector(saveAndClose))
        saveBtn.keyEquivalent = "\r"

        actionsStack.addArrangedSubview(copyBtn)
        actionsStack.addArrangedSubview(saveBtn)
        toolbar.addSubview(actionsStack)
    }

    private func createButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        return button
    }

    // MARK: - Tool Selectors

    @objc private func arrowToolSelected() { canvasView.currentTool = .arrow }
    @objc private func rectToolSelected() { canvasView.currentTool = .rectangle }
    @objc private func roundRectToolSelected() { canvasView.currentTool = .roundedRectangle }
    @objc private func ellipseToolSelected() { canvasView.currentTool = .ellipse }
    @objc private func counterToolSelected() { canvasView.currentTool = .stepCounter }

    @objc private func toggleBackdrop() {
        if !isBackgroundApplied {
            let styled = BackgroundStyler.apply(image: canvasView.baseImage, options: BackgroundStyleOptions())
            canvasView.baseImage = styled
            isBackgroundApplied = true
        }
    }

    @objc private func copyAndClose() {
        let finalImage = canvasView.exportFlattenedImage()
        QuickAccessOverlayController.shared.copyImageToClipboard(finalImage)
        orderOut(nil)
    }

    @objc private func saveAndClose() {
        let finalImage = canvasView.exportFlattenedImage()
        QuickAccessOverlayController.shared.saveImageToDisk(finalImage)
        orderOut(nil)
    }
}

/// Coordinator for opening and managing the Annotation Editor Window.
@MainActor
public final class AnnotationEditorCoordinator {
    public static let shared = AnnotationEditorCoordinator()

    private var activeEditor: AnnotationEditorWindow?

    private init() {}

    public func openEditor(with image: NSImage) {
        let window = AnnotationEditorWindow(image: image)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        activeEditor = window
    }
}
