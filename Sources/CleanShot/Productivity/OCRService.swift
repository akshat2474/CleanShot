import AppKit
import Vision

/// On-device OCR and QR code recognition service using the Apple Vision framework.
public final class OCRService: Sendable {
    public static let shared = OCRService()

    private init() {}

    public func recognizeText(from image: CGImage) async -> String {
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }

                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }

                let fullText = recognizedStrings.joined(separator: "\n")
                continuation.resume(returning: fullText)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: "")
            }
        }
    }

    public func scanQRCode(from image: CGImage) async -> String? {
        return await withCheckedContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, error in
                guard error == nil,
                      let barcodes = request.results as? [VNBarcodeObservation] else {
                    continuation.resume(returning: nil)
                    return
                }

                let qrCode = barcodes.first { $0.symbology == .qr }
                continuation.resume(returning: qrCode?.payloadStringValue)
            }

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    @MainActor
    public func processImageAndCopyToClipboard(_ image: NSImage) async {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }

        // Check for QR code first
        if let qrContent = await scanQRCode(from: cgImage), !qrContent.isEmpty {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(qrContent, forType: .string)
            NSSound.beep()
            return
        }

        // Text recognition
        let text = await recognizeText(from: cgImage)
        guard !text.isEmpty else { return }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        NSSound.beep()
    }
}
