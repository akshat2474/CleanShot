import XCTest
@testable import CleanShot

final class CleanShotTests: XCTestCase {

    func testAppKitToCoreGraphicsConversion() {
        let primaryHeight: CGFloat = 1080.0
        // A rect at bottom-left: (x: 100, y: 100, w: 200, h: 300)
        let appKitRect = CGRect(x: 100, y: 100, width: 200, height: 300)
        let cgRect = DisplayCoordinateConverter.toCoreGraphics(rect: appKitRect, primaryScreenHeight: primaryHeight)

        // Expected cgY = 1080 - (100 + 300) = 680
        XCTAssertEqual(cgRect.origin.x, 100)
        XCTAssertEqual(cgRect.origin.y, 680)
        XCTAssertEqual(cgRect.width, 200)
        XCTAssertEqual(cgRect.height, 300)

        // Convert back
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
        // Multi-monitor setup where second display is at (x: 1920, y: 0)
        let displayBounds = CGRect(x: 1920, y: 0, width: 1920, height: 1080)
        let globalRect = CGRect(x: 2000, y: 100, width: 400, height: 300)

        let localRect = DisplayCoordinateConverter.toLocalDisplayRect(globalRect: globalRect, displayBounds: displayBounds)
        XCTAssertEqual(localRect.origin.x, 80)
        XCTAssertEqual(localRect.origin.y, 100)
        XCTAssertEqual(localRect.width, 400)
        XCTAssertEqual(localRect.height, 300)
    }
}
