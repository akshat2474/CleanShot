import AppKit
import CoreGraphics

/// Magnifier Loupe view providing a 10x pixel grid, color sampler, and selection dimensions badge.
public final class MagnifierLoupeView: NSView {

    // MARK: - Properties

    public var sampleImage: CGImage? {
        didSet { needsDisplay = true }
    }

    public var samplePoint: CGPoint = .zero {
        didSet { needsDisplay = true }
    }

    public var selectionDimensions: CGSize = .zero {
        didSet { needsDisplay = true }
    }

    private let loupeDiameter: CGFloat = 120.0
    private let gridSize: Int = 11 // 11x11 pixel grid

    // MARK: - Initializer

    public init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 140, height: 175))
        wantsLayer = true
        layer?.masksToBounds = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Drawing

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let circleRect = CGRect(x: 10, y: 45, width: loupeDiameter, height: loupeDiameter)

        drawLoupeContent(in: circleRect, context: context)
        drawLoupeFrame(in: circleRect, context: context)
        drawInfoBadge(context: context)
    }

    // MARK: - Sub-drawers

    private func drawLoupeContent(in rect: CGRect, context: CGContext) {
        context.saveGState()

        // Clip to circle
        let clipPath = CGPath(ellipseIn: rect, transform: nil)
        context.addPath(clipPath)
        context.clip()

        // Background
        context.setFillColor(CGColor(gray: 0.1, alpha: 1.0))
        context.fill(rect)

        if let sampleImage = sampleImage {
            drawPixelGrid(in: rect, image: sampleImage, context: context)
        }

        // Center pixel reticle
        let cellSize = rect.width / CGFloat(gridSize)
        let centerIndex = CGFloat(gridSize / 2)
        let centerCellRect = CGRect(
            x: rect.origin.x + (centerIndex * cellSize),
            y: rect.origin.y + (centerIndex * cellSize),
            width: cellSize,
            height: cellSize
        )

        context.setStrokeColor(CGColor(red: 0.18, green: 0.46, blue: 1.0, alpha: 1.0)) // CleanShot blue
        context.setLineWidth(2.0)
        context.stroke(centerCellRect)

        context.restoreGState()
    }

    private func drawPixelGrid(in rect: CGRect, image: CGImage, context: CGContext) {
        let halfGrid = gridSize / 2
        let cellSize = rect.width / CGFloat(gridSize)

        let startX = Int(samplePoint.x) - halfGrid
        let startY = Int(samplePoint.y) - halfGrid

        // Grid lines
        context.setStrokeColor(CGColor(gray: 0.5, alpha: 0.2))
        context.setLineWidth(0.5)

        for col in 0..<gridSize {
            for row in 0..<gridSize {
                let pixelX = startX + col
                let pixelY = startY + row

                let cellRect = CGRect(
                    x: rect.origin.x + (CGFloat(col) * cellSize),
                    y: rect.origin.y + (CGFloat(row) * cellSize),
                    width: cellSize,
                    height: cellSize
                )

                if let color = samplePixelColor(from: image, x: pixelX, y: pixelY) {
                    context.setFillColor(color)
                    context.fill(cellRect)
                }

                context.stroke(cellRect)
            }
        }
    }

    private func drawLoupeFrame(in rect: CGRect, context: CGContext) {
        context.saveGState()

        // White border ring with outer drop shadow
        context.setStrokeColor(CGColor(gray: 1.0, alpha: 0.9))
        context.setLineWidth(3.0)
        context.strokeEllipse(in: rect.insetBy(dx: 1.5, dy: 1.5))

        context.restoreGState()
    }

    private func drawInfoBadge(context: CGContext) {
        let badgeRect = CGRect(x: 5, y: 5, width: 130, height: 32)
        let badgePath = CGPath(roundedRect: badgeRect, cornerWidth: 6, cornerHeight: 6, transform: nil)

        context.saveGState()
        context.setFillColor(CGColor(gray: 0.12, alpha: 0.92))
        context.addPath(badgePath)
        context.fillPath()

        // 1px border
        context.setStrokeColor(CGColor(gray: 1.0, alpha: 0.15))
        context.setLineWidth(1.0)
        context.addPath(badgePath)
        context.strokePath()
        context.restoreGState()

        // Color & Dimensions Text
        let hexString = sampleHexColor()
        let dimensionText = "\(Int(selectionDimensions.width)) × \(Int(selectionDimensions.height)) px"

        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 9.5, weight: .medium),
            .foregroundColor: NSColor.white
        ]

        let colorAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 9.0, weight: .regular),
            .foregroundColor: NSColor(white: 0.75, alpha: 1.0)
        ]

        let dimString = NSAttributedString(string: dimensionText, attributes: textAttributes)
        let hexAttrString = NSAttributedString(string: hexString, attributes: colorAttributes)

        dimString.draw(at: NSPoint(x: 12, y: 21))
        hexAttrString.draw(at: NSPoint(x: 12, y: 8))
    }

    // MARK: - Pixel Sampling

    private func samplePixelColor(from image: CGImage, x: Int, y: Int) -> CGColor? {
        guard x >= 0 && x < image.width && y >= 0 && y < image.height else {
            return CGColor(gray: 0.0, alpha: 1.0)
        }

        guard let dataProvider = image.dataProvider,
              let data = dataProvider.data,
              let ptr = CFDataGetBytePtr(data) else {
            return nil
        }

        let bytesPerPixel = image.bitsPerPixel / 8
        let bytesPerRow = image.bytesPerRow
        let offset = (y * bytesPerRow) + (x * bytesPerPixel)

        let r = CGFloat(ptr[offset]) / 255.0
        let g = CGFloat(ptr[offset + 1]) / 255.0
        let b = CGFloat(ptr[offset + 2]) / 255.0

        return CGColor(red: r, green: g, blue: b, alpha: 1.0)
    }

    private func sampleHexColor() -> String {
        guard let sampleImage = sampleImage,
              let color = samplePixelColor(from: sampleImage, x: Int(samplePoint.x), y: Int(samplePoint.y)),
              let components = color.components, components.count >= 3 else {
            return "#000000"
        }

        let r = Int(round(components[0] * 255))
        let g = Int(round(components[1] * 255))
        let b = Int(round(components[2] * 255))

        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
