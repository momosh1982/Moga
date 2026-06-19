import Foundation

// Drives a complete scan session:
// for each position → for each focus step → send PhotoPacket → collect chunks → notify delegate

@Observable
final class ScanController {
    enum State { case idle, scanning, paused, complete, failed(String) }

    private(set) var state: State = .idle
    private(set) var currentPositionIndex: Int = 0
    private(set) var totalPositions: Int = 0

    var onBundleComplete: ((Int, [Data]) -> Void)?   // (positionIndex, imageDataArray)

    private let session: DeviceSession
    private let focusConfig: FocusStackConfig
    private var positions: [ScanPosition] = []
    private var bundles: [Int: ImageBundle] = [:]

    init(session: DeviceSession, focusConfig: FocusStackConfig) {
        self.session = session
        self.focusConfig = focusConfig

        session.tcp.onPacket = { [weak self] type, data in
            self?.handlePacket(type: type, data: data)
        }
    }

    // MARK: - Start

    func start(pattern: ScanPattern, photoCount: Int) {
        guard case .ready = session.state else { return }
        positions = pattern.positions(count: photoCount)
        totalPositions = positions.count
        currentPositionIndex = 0
        bundles = [:]
        state = .scanning
        captureNext()
    }

    func cancel() {
        state = .idle
    }

    // MARK: - Capture sequence

    private func captureNext() {
        guard case .scanning = state else { return }
        guard currentPositionIndex < positions.count else {
            state = .complete
            return
        }

        let pos = positions[currentPositionIndex]
        let steps = focusConfig.focusSteps()
        let stackSize = steps.count

        bundles[currentPositionIndex] = ImageBundle(
            positionIndex: currentPositionIndex,
            expectedStackSize: stackSize
        )

        // Move motors to position
        session.moveMotor(.rotor,      angle: pos.rotorAngle,     mode: .absolute)
        session.moveMotor(.turntable,  angle: pos.turntableAngle, mode: .absolute)

        // Send one Photo packet per focus step
        for (stackIndex, diopters) in steps.enumerated() {
            let packet = PhotoPacket(
                focusDiopters:   diopters,
                rotorAngle:      pos.rotorAngle,
                turntableAngle:  pos.turntableAngle,
                delayMs:         200,
                stackIndex:      UInt16(stackIndex)
            )
            session.tcp.send(type: .photo, payload: packet.encode())
        }
    }

    // MARK: - Incoming packet handling

    private func handlePacket(type: PacketType, data: Data) {
        guard type == .chunk, let chunk = ChunkPacket.decode(from: data) else { return }

        let posIndex = Int(chunk.positionIndex)
        bundles[posIndex]?.addChunk(chunk)

        if let bundle = bundles[posIndex], bundle.isComplete {
            let images = bundle.assembledImages()
            DispatchQueue.main.async { [weak self] in
                self?.onBundleComplete?(posIndex, images)
            }
            currentPositionIndex += 1
            captureNext()
        }
    }
}
