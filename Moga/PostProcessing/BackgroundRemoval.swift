import Foundation
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

// Removes the background from a CGImage using Apple's Vision subject-lifting API.
// Requires macOS 14+; falls back to returning the original image on older systems.

final class BackgroundRemoval {

    func removeBackground(from image: CGImage) async -> CGImage {
        guard #available(macOS 14.0, *) else { return image }

        return await withCheckedContinuation { continuation in
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cgImage: image)

            do {
                try handler.perform([request])
                guard let result = request.results?.first else {
                    continuation.resume(returning: image)
                    return
                }

                let maskBuffer = try result.generateScaledMaskForImage(
                    forInstances: result.allInstances,
                    from: handler
                )

                let ciImage    = CIImage(cgImage: image)
                let maskImage  = CIImage(cvPixelBuffer: maskBuffer)

                let blendFilter = CIFilter.blendWithMask()
                blendFilter.inputImage      = ciImage
                blendFilter.backgroundImage = CIImage.empty()
                blendFilter.maskImage       = maskImage

                let context = CIContext()
                if let output = blendFilter.outputImage,
                   let result = context.createCGImage(output, from: ciImage.extent) {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(returning: image)
                }
            } catch {
                print("BackgroundRemoval: \(error)")
                continuation.resume(returning: image)
            }
        }
    }
}
