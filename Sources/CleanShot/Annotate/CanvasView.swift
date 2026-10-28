import AppKit

public enum AnnotationTool: Sendable {
    case arrow
    case rectangle
    case roundedRectangle
    case ellipse
    case stepCounter
}

/// Interactive drawing canvas for markup annotations.
public final class CanvasView: NSView {

    public var baseImage: NSImage {
        didSet {
            frame.size = baseImage.size
            needsDisplay = true
        }
    }

    public var currentTool: AnnotationTool = .arrow
    public var activeColor: NSColor = .systemRed
    public var strokeWidth: CGFloat = 3.0

    private var elements: [any AnnotationElement] = []
    private var counterIndex: Int = 1

    // Active Drawing State
    private var dragStart: CGPoint?
    private var currentDrag: CGPoint?
    private var isDrawing: Bool = false

    public init(baseImage: NSImage) {
        self.baseImage = baseImage
        super.init(frame: NSRect(origin: .zero, size: baseImage.size))
        self.wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Drawing

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // 1. Draw base screenshot
        baseImage.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1.0)

        // 2. Draw committed annotation elements
        for element in elements {
            element.draw(in: context)
        }

        // 3. Draw active in-progress preview element
        drawActivePreview(in: context)
    }

    private func drawActivePreview(in context: CGContext) {
        guard isDrawing, let start = dragStart, let current = currentDrag else { return }

        switch currentTool {
        case .arrow:
            let previewArrow = ArrowElement(startPoint: start, endPoint: current, strokeWidth: strokeWidth, color: activeColor)
            previewArrow.draw(in: context)
        case .rectangle:
            let rect = makeRect(from: start, to: current)
            let previewShape = ShapeElement(rect: rect, type: .rectangle, strokeWidth: strokeWidth, strokeColor: activeColor)
            previewShape.draw(in: context)
        case .roundedRectangle:
            let rect = makeRect(from: start, to: current)
            let previewShape = ShapeElement(rect: rect, type: .roundedRectangle(radius: 8.0), strokeWidth: strokeWidth, strokeColor: activeColor)
            previewShape.draw(in: context)
        case .ellipse:
            let rect = makeRect(from: start, to: current)
            let previewShape = ShapeElement(rect: rect, type: .ellipse, strokeWidth: strokeWidth, strokeColor: activeColor)
            previewShape.draw(in: context)
        case .stepCounter:
            let previewCounter = CounterElement(center: current, number: counterIndex, radius: 14.0, color: activeColor)
            previewCounter.draw(in: context)
        }
    }

    // MARK: - Mouse Events

    public override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        dragStart = location
        currentDrag = location
        isDrawing = true

        if currentTool == .stepCounter {
            let counter = CounterElement(center: location, number: counterIndex, radius: 14.0, color: activeColor)
            addElement(counter)
            counterIndex += 1
            isDrawing = false
            needsDisplay = true
        }
    }

    public override func mouseDragged(with event: NSEvent) {
        guard isDrawing else { return }
        currentDrag = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    public override func mouseUp(with event: NSEvent) {
        guard isDrawing, let start = dragStart, let current = currentDrag else { return }
        isDrawing = false

        switch currentTool {
        case .arrow:
            guard distance(start, current) > 4 else { return }
            let arrow = ArrowElement(startPoint: start, endPoint: current, strokeWidth: strokeWidth, color: activeColor)
            addElement(arrow)
        case .rectangle:
            let rect = makeRect(from: start, to: current)
            guard rect.width > 3 && rect.height > 3 else { return }
            let shape = ShapeElement(rect: rect, type: .rectangle, strokeWidth: strokeWidth, strokeColor: activeColor)
            addElement(shape)
        case .roundedRectangle:
            let rect = makeRect(from: start, to: current)
            guard rect.width > 3 && rect.height > 3 else { return }
            let shape = ShapeElement(rect: rect, type: .roundedRectangle(radius: 8.0), strokeWidth: strokeWidth, strokeColor: activeColor)
            addElement(shape)
        case .ellipse:
            let rect = makeRect(from: start, to: current)
            guard rect.width > 3 && rect.height > 3 else { return }
            let shape = ShapeElement(rect: rect, type: .ellipse, strokeWidth: strokeWidth, strokeColor: activeColor)
            addElement(shape)
        case .stepCounter:
            break
        }

        needsDisplay = true
    }

    // MARK: - Element Management & Undo

    public func addElement(_ element: any AnnotationElement) {
        elements.append(element)
        undoManager?.registerUndo(withTarget: self) { target in
            target.removeLastElement()
        }
        needsDisplay = true
    }

    public func removeLastElement() {
        guard !elements.isEmpty else { return }
        elements.removeLast()
        needsDisplay = true
    }

    // MARK: - Export

    public func exportFlattenedImage() -> NSImage {
        let exportImage = NSImage(size: bounds.size)
        exportImage.lockFocus()

        if let context = NSGraphicsContext.current?.cgContext {
            baseImage.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1.0)
            for element in elements {
                element.draw(in: context)
            }
        }

        exportImage.unlockFocus()
        return exportImage
    }

    // MARK: - Geometry Helpers

    private func makeRect(from p1: CGPoint, to p2: CGPoint) -> CGRect {
        return CGRect(
            x: min(p1.x, p2.x),
            y: min(p1.y, p2.y),
            width: abs(p2.x - p1.x),
            height: abs(p2.y - p1.y)
        )
    }

    private func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        return hypot(p2.x - p1.x, p2.y - p1.y)
    }
}
