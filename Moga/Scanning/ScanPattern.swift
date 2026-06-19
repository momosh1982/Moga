import Foundation

struct ScanPosition {
    let rotorAngle: Float       // degrees, vertical axis
    let turntableAngle: Float   // degrees, horizontal axis
}

enum ScanPattern: String, CaseIterable {
    case spiral     = "Spiral"
    case fibonacci  = "Fibonacci"
    case uniform    = "Uniform"

    func positions(count: Int) -> [ScanPosition] {
        switch self {
        case .spiral:     return spiral(count: count)
        case .fibonacci:  return fibonacci(count: count)
        case .uniform:    return uniform(count: count)
        }
    }

    // MARK: - Pattern generators

    private func uniform(count: Int) -> [ScanPosition] {
        let rows = max(1, Int(sqrt(Double(count))))
        let cols = max(1, count / rows)
        var positions: [ScanPosition] = []
        for r in 0..<rows {
            for c in 0..<cols {
                let rotor     = Float(r) / Float(rows) * 180 - 90
                let turntable = Float(c) / Float(cols) * 360
                positions.append(ScanPosition(rotorAngle: rotor, turntableAngle: turntable))
            }
        }
        return positions
    }

    private func spiral(count: Int) -> [ScanPosition] {
        (0..<count).map { i in
            let t         = Float(i) / Float(max(count - 1, 1))
            let rotor     = t * 180 - 90
            let turntable = Float(i) * 137.5   // golden angle step
            return ScanPosition(rotorAngle: rotor, turntableAngle: turntable.truncatingRemainder(dividingBy: 360))
        }
    }

    private func fibonacci(count: Int) -> [ScanPosition] {
        let goldenRatio: Float = (1 + sqrt(5.0)) / 2
        return (0..<count).map { i in
            let theta     = acos(1 - 2 * Float(i + 1) / Float(count + 1)) * 180 / .pi - 90
            let phi       = (Float(i) / goldenRatio) * 360
            return ScanPosition(rotorAngle: theta, turntableAngle: phi.truncatingRemainder(dividingBy: 360))
        }
    }
}
