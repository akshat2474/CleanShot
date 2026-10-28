import XCTest
import Carbon
@testable import CleanShot

final class CleanShotTests: XCTestCase {

    // MARK: - Coordinate Converter Tests

    func testAppKitToCoreGraphicsConversion() {
        let primaryHeight: CGFloat = 1080.0
        let appKitRect = CGRect(x: 100, y: 100, width: 200, height: 300)
        let cgRect = DisplayCoordinateConverter.toCoreGraphics(rect: appKitRect, primaryScreenHeight: primaryHeight)

        // Expected cgY = 1080 - (100 + 300) = 680
        XCTAssertEqual(cgRect.origin.x, 100)
        XCTAssertEqual(cgRect.origin.y, 680)
        XCTAssertEqual(cgRect.width, 200)
        XCTAssertEqual(cgRect.height, 300)

        // Round trip back to AppKit
        let roundTrip = DisplayCoordinateConverter.toAppKit(rect: cgRect, primaryScreenHeight: primaryHeight)
        XCTAssertEqual(roundTrip, appKitRect)
    }

    func testPixelRectScaling() {
        let pointRect = CGRect(x: 10, y: 20, width: 150, height: 250)
        let pixelRect = DisplayCoordinateConverter.toPixelRect(pointRect: pointRect, scaleFactor: 2.0)

        XCTAssertEqual(pixelRect.origin.x, 20)
        XCTAssertEqual(pixelRect.origin.y, 40)
        XCTAssertEqual(pixelRect.width, 300)
        XCTAssertEqual(pixelRect.height, 500)
    }

    func testLocalDisplayRectTranslation() {
        let displayBounds = CGRect(x: 1920, y: 0, width: 1920, height: 1080)
        let globalRect = CGRect(x: 2000, y: 100, width: 400, height: 300)

        let localRect = DisplayCoordinateConverter.toLocalDisplayRect(globalRect: globalRect, displayBounds: displayBounds)
        XCTAssertEqual(localRect.origin.x, 80)
        XCTAssertEqual(localRect.origin.y, 100)
        XCTAssertEqual(localRect.width, 400)
        XCTAssertEqual(localRect.height, 300)
    }

    // MARK: - Capture Action Tests

    func testCaptureActionShortcutsAndKeycodes() {
        let allActions = CaptureAction.allCases
        XCTAssertEqual(allActions.count, 8)

        // Verify key codes
        XCTAssertEqual(CaptureAction.captureArea.defaultKeyCode, 21) // '4'
        XCTAssertEqual(CaptureAction.captureWindow.defaultKeyCode, 23) // '5'
        XCTAssertEqual(CaptureAction.captureFullscreen.defaultKeyCode, 20) // '3'
        XCTAssertEqual(CaptureAction.capturePreviousArea.defaultKeyCode, 22) // '6'
        XCTAssertEqual(CaptureAction.scrollingCapture.defaultKeyCode, 26) // '7'
        XCTAssertEqual(CaptureAction.selfTimer.defaultKeyCode, 28) // '8'
        XCTAssertEqual(CaptureAction.recognizeText.defaultKeyCode, 19) // '2'
        XCTAssertEqual(CaptureAction.recordScreen.defaultKeyCode, 25) // '9'

        // Verify modifiers are Cmd + Shift
        for action in allActions {
            XCTAssertEqual(action.defaultModifiers, UInt32(cmdKey | shiftKey))
            XCTAssertFalse(action.title.isEmpty)
            XCTAssertFalse(action.shortcutDisplayString.isEmpty)
        }
    }

    // MARK: - Background Styler Geometry Tests

    func testBackgroundStylerGeometryCalculation() {
        let baseSize = NSSize(width: 400, height: 300)
        let baseImage = NSImage(size: baseSize)
        baseImage.lockFocus()
        NSColor.blue.setFill()
        NSRect(origin: .zero, size: baseSize).fill()
        baseImage.unlockFocus()

        let options = BackgroundStyleOptions(
            backdrop: .transparent,
            padding: 50.0,
            cornerRadius: 10.0,
            shadowRadius: 15.0
        )

        let styledImage = BackgroundStyler.apply(image: baseImage, options: options)

        // Target size must be baseSize + (padding * 2)
        XCTAssertEqual(styledImage.size.width, 500) // 400 + 100
        XCTAssertEqual(styledImage.size.height, 400) // 300 + 100
    }

    // MARK: - Vector Annotation Elements Tests

    func testAnnotationElementsRendering() {
        let context = CGContext(
            data: nil,
            width: 200,
            height: 200,
            bitsPerComponent: 8,
            bytesPerRow: 200 * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!

        // Arrow
        let arrow = ArrowElement(startPoint: CGPoint(x: 10, y: 10), endPoint: CGPoint(x: 100, y: 100))
        arrow.draw(in: context)

        // Shape
        let shape = ShapeElement(rect: CGRect(x: 20, y: 20, width: 60, height: 60), type: .rectangle)
        shape.draw(in: context)

        // Counter
        let counter = CounterElement(center: CGPoint(x: 50, y: 50), number: 1)
        counter.draw(in: context)

        let renderedImage = context.makeImage()
        XCTAssertNotNil(renderedImage)
        XCTAssertEqual(renderedImage?.width, 200)
        XCTAssertEqual(renderedImage?.height, 200)
    }

    // MARK: - Overlay Window Tests

    @MainActor
    func testAreaCaptureOverlayWindowInitialization() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: 100,
            height: 100,
            bitsPerComponent: 8,
            bytesPerRow: 100 * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        let dummyImage = context.makeImage()!
        let snapshot = ScreenSnapshot(
            screen: screen,
            image: dummyImage,
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            scaleFactor: 2.0
        )

        let overlayWindow = AreaCaptureOverlayWindow(snapshot: snapshot, primaryScreenHeight: 600)
        XCTAssertNotNil(overlayWindow)
        XCTAssertEqual(overlayWindow.frame.size.width, 800)
        XCTAssertEqual(overlayWindow.frame.size.height, 600)
        XCTAssertTrue(overlayWindow.canBecomeKey)
        XCTAssertTrue(overlayWindow.canBecomeMain)
    }
}
