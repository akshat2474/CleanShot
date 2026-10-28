import XCTest
import CoreGraphics
import AppKit
@testable import CleanShot

final class CleanShotPerformanceTests: XCTestCase {

    // MARK: - Benchmark 1: Coordinate Math Throughput

    func testCoordinateConversionPerformance() {
        let primaryHeight: CGFloat = 1080.0
        let testRect = CGRect(x: 120, y: 340, width: 800, height: 600)

        // Measure 100,000 coordinate conversions
        measure {
            for _ in 0..<100_000 {
                _ = DisplayCoordinateConverter.toCoreGraphics(rect: testRect, primaryScreenHeight: primaryHeight)
            }
        }
    }

    // MARK: - Benchmark 2: 4K Image Cropping Latency

    func test4KImageCroppingPerformance() {
        // Create a synthetic 4K bitmap (3840 x 2160)
        let width = 3840
        let height = 2160
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let synthetic4K = context.makeImage()!

        let cropRect = CGRect(x: 400, y: 300, width: 1920, height: 1080)

        measure {
            for _ in 0..<50 {
                _ = synthetic4K.cropping(to: cropRect)
            }
        }
    }

    // MARK: - Benchmark 3: Background Styler & Drop Shadow Rendering

    func testBackgroundStylerRenderingPerformance() {
        // Create 1920x1080 base image
        let baseSize = NSSize(width: 1920, height: 1080)
        let baseImage = NSImage(size: baseSize)
        baseImage.lockFocus()
        NSColor.darkGray.setFill()
        NSRect(origin: .zero, size: baseSize).fill()
        baseImage.unlockFocus()

        let options = BackgroundStyleOptions(
            backdrop: .gradient(
                start: NSColor.systemBlue,
                end: NSColor.systemPurple
            ),
            padding: 40.0,
            cornerRadius: 12.0,
            shadowRadius: 20.0,
            shadowOpacity: 0.4
        )

        measure {
            _ = BackgroundStyler.apply(image: baseImage, options: options)
        }
    }

    // MARK: - Benchmark 4: Vector Markup Drawing Latency

    func testVectorMarkupRenderingPerformance() {
        let width = 1920
        let height = 1080
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!

        // Create 300 vector elements (100 arrows, 100 shapes, 100 step counters)
        var elements: [any AnnotationElement] = []
        for i in 0..<100 {
            let offset = CGFloat(i * 10)
            elements.append(ArrowElement(startPoint: CGPoint(x: offset, y: offset), endPoint: CGPoint(x: offset + 100, y: offset + 100)))
            elements.append(ShapeElement(rect: CGRect(x: offset, y: offset, width: 80, height: 60), type: .rectangle))
            elements.append(CounterElement(center: CGPoint(x: offset + 40, y: offset + 30), number: i + 1))
        }

        measure {
            for element in elements {
                element.draw(in: context)
            }
        }
    }
}
