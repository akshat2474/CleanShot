import AppKit

public enum ShapeType: Sendable {
    case rectangle
    case roundedRectangle(radius: CGFloat)
    case ellipse
    case line
}

public enum RedactionType: Sendable {
    case pixelate(blockSize: CGFloat)
    case blur(radius: CGFloat)
    case spotlight
}

/// Abstract protocol for all vector annotation elements.
public protocol AnnotationElement: Sendable {
    var id: UUID { get }
    func draw(in context: CGContext)
}

// MARK: - Arrow Element

public struct ArrowElement: AnnotationElement {
    public let id: UUID = UUID()
    public var startPoint: CGPoint
    public var endPoint: CGPoint
    public var isCurved: Bool
    public var controlPoint: CGPoint?
    public var strokeWidth: CGFloat
    public var color: NSColor

    public init(
        startPoint: CGPoint,
        endPoint: CGPoint,
        isCurved: Bool = false,
        controlPoint: CGPoint? = nil,
        strokeWidth: CGFloat = 3.0,
        color: NSColor = .systemRed
    ) {
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.isCurved = isCurved
        self.controlPoint = controlPoint
        self.strokeWidth = strokeWidth
        self.color = color
    }

    public func draw(in context: CGContext) {
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setFillColor(color.cgColor)
        context.setLineWidth(strokeWidth)
        context.setLineCap(.round)

        // Draw shaft
        let path = CGMutablePath()
        path.move(to: startPoint)
        if isCurved, let cp = controlPoint {
            path.addQuadCurve(to: endPoint, control: cp)
        } else {
            path.addLine(to: endPoint)
        }
        context.addPath(path)
        context.strokePath()

        // Draw arrowhead
        let angle = isCurved && controlPoint != nil
            ? atan2(endPoint.y - controlPoint!.y, endPoint.x - controlPoint!.x)
            : atan2(endPoint.y - startPoint.y, endPoint.x - startPoint.x)

        let arrowLength: CGFloat = 16.0
        let arrowAngle: CGFloat = .pi / 6.0 // 30 degrees

        let p1 = CGPoint(
            x: endPoint.x - arrowLength * cos(angle - arrowAngle),
            y: endPoint.y - arrowLength * sin(angle - arrowAngle)
        )
        let p2 = CGPoint(
            x: endPoint.x - arrowLength * cos(angle + arrowAngle),
            y: endPoint.y - arrowLength * sin(angle + arrowAngle)
        )

        let headPath = CGMutablePath()
        headPath.move(to: endPoint)
        headPath.addLine(to: p1)
        headPath.addLine(to: p2)
        headPath.closeSubpath()

        context.addPath(headPath)
        context.fillPath()

        context.restoreGState()
    }
}

// MARK: - Shape Element

public struct ShapeElement: AnnotationElement {
    public let id: UUID = UUID()
    public var rect: CGRect
    public var type: ShapeType
    public var strokeWidth: CGFloat
    public var strokeColor: NSColor
    public var fillColor: NSColor?

    public init(rect: CGRect, type: ShapeType, strokeWidth: CGFloat = 2.5, strokeColor: NSColor = .systemRed, fillColor: NSColor? = nil) {
        self.rect = rect
        self.type = type
        self.strokeWidth = strokeWidth
        self.strokeColor = strokeColor
        self.fillColor = fillColor
    }

    public func draw(in context: CGContext) {
        context.saveGState()
        context.setLineWidth(strokeWidth)
        context.setStrokeColor(strokeColor.cgColor)

        if let fill = fillColor {
            context.setFillColor(fill.cgColor)
        }

        switch type {
        case .rectangle:
            if fillColor != nil { context.fill(rect) }
            context.stroke(rect)
        case .roundedRectangle(let radius):
            let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
            if fillColor != nil {
                context.addPath(path)
                context.fillPath()
            }
            context.addPath(path)
            context.strokePath()
        case .ellipse:
            if fillColor != nil { context.fillEllipse(in: rect) }
            context.strokeEllipse(in: rect)
        case .line:
            context.strokeLineSegments(between: [rect.origin, CGPoint(x: rect.maxX, y: rect.maxY)])
        }

        context.restoreGState()
    }
}

// MARK: - Step Counter Element

public struct CounterElement: AnnotationElement {
    public let id: UUID = UUID()
    public var center: CGPoint
    public var number: Int
    public var radius: CGFloat
    public var color: NSColor

    public init(center: CGPoint, number: Int, radius: CGFloat = 14.0, color: NSColor = .systemBlue) {
        self.center = center
        self.number = number
        self.radius = radius
        self.color = color
    }

    public func draw(in context: CGContext) {
        let circleRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)

        context.saveGState()
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: circleRect)

        // Drop shadow & border
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(1.5)
        context.strokeEllipse(in: circleRect)
        context.restoreGState()

        // Text numeral
        let text = "\(number)" as NSString
        let font = NSFont.systemFont(ofSize: radius * 1.1, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let textSize = text.size(withAttributes: attrs)
        let textPoint = CGPoint(x: center.x - (textSize.width / 2), y: center.y - (textSize.height / 2))
        text.draw(at: textPoint, withAttributes: attrs)
    }
}
