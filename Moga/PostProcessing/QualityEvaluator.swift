import Foundation
import CoreImage

// Scores image sharpness using Laplacian variance — higher = sharper.
// Used for live focus peaking to help the user find the right focus distance.

final class QualityEvaluator {

    func sharpnessScore(for image: CGImage) -> Float {
        let width  = image.width
        let height = image.height
        let pixelCount = width * height

        var pixels = [UInt8](repeating: 0, count: pixelCount * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let ctx = CGContext(data: &pixels, width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: width * 4,
                                  space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else { return 0 }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Compute luminance
        var luma = [Float](repeating: 0, count: pixelCount)
        for i in 0..<pixelCount {
            luma[i] = 0.299 * Float(pixels[i * 4])
                    + 0.587 * Float(pixels[i * 4 + 1])
                    + 0.114 * Float(pixels[i * 4 + 2])
        }

        // Laplacian variance
        var sum: Float = 0
        var count = 0
        for y in 1..<height - 1 {
            for x in 1..<width - 1 {
                let idx = y * width + x
                let lap = 4 * luma[idx]
                    - luma[idx - 1] - luma[idx + 1]
                    - luma[idx - width] - luma[idx + width]
                sum += lap * lap
                count += 1
            }
        }
        return count > 0 ? sum / Float(count) : 0
    }
}
