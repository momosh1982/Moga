import Foundation

// Focus stacking configuration derived from the OpenScan3 Node-RED flow.
// Interpolates focus distances linearly between near and far in `stackSize` steps.

@Observable
final class FocusStackConfig {
    var enabled: Bool    = false
    var nearDiopters: Float = 2.0   // close focus (higher = closer)
    var farDiopters: Float  = 0.5   // far focus
    var stackSize: Int   = 5        // number of images per position (2–20)

    var clampedStackSize: Int { min(max(stackSize, 2), 20) }

    // Returns focus distances for each frame at a given scan position.
    func focusSteps() -> [Float] {
        guard enabled else { return [nearDiopters] }
        let count = clampedStackSize
        if count == 1 { return [nearDiopters] }
        return (0..<count).map { i in
            let t = Float(i) / Float(count - 1)
            return nearDiopters + t * (farDiopters - nearDiopters)
        }
    }
}
