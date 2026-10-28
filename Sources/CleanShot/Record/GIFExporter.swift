import AppKit
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

/// Converts video files to optimized animated GIFs using ImageIO and frame quantization.
public final class GIFExporter: Sendable {

    public static func exportGIF(
        from videoURL: URL,
        outputURL: URL,
        fps: Int = 15,
        maxPixelWidth: CGFloat = 800,
        completion: @escaping @Sendable (Bool) -> Void
    ) {
        Task {
            let asset = AVAsset(url: videoURL)
            guard let _ = try? await asset.loadTracks(withMediaType: .video).first else {
                completion(false)
                return
            }

            let duration = try? await asset.load(.duration)
            let totalSeconds = CMTimeGetSeconds(duration ?? .zero)
            guard totalSeconds > 0 else {
                completion(false)
                return
            }

            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: maxPixelWidth, height: maxPixelWidth)
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero

            let frameCount = Int(totalSeconds * Double(fps))
            guard frameCount > 0 else {
                completion(false)
                return
            }

            guard let destination = CGImageDestinationCreateWithURL(
                outputURL as CFURL,
                UTType.gif.identifier as CFString,
                frameCount,
                nil
            ) else {
                completion(false)
                return
            }

            let fileProperties: [String: Any] = [
                kCGImagePropertyGIFDictionary as String: [
                    kCGImagePropertyGIFLoopCount as String: 0 // Infinite loop
                ]
            ]
            CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)

            let frameDelay = 1.0 / Double(fps)
            let frameProperties: [String: Any] = [
                kCGImagePropertyGIFDictionary as String: [
                    kCGImagePropertyGIFDelayTime as String: frameDelay
                ]
            ]

            for i in 0..<frameCount {
                let time = CMTime(seconds: Double(i) * frameDelay, preferredTimescale: 600)
                if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                    CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
                }
            }

            let success = CGImageDestinationFinalize(destination)
            completion(success)
        }
    }
}
