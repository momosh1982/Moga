import Foundation
import Network

// Manages the TCP connection to the OpenScan device on port 2050.
// Sends encoded packets and delivers incoming packets via a callback.

@Observable
final class TCPClient {
    enum State { case disconnected, connecting, connected, failed(Error) }

    private(set) var state: State = .disconnected

    var onPacket: ((PacketType, Data) -> Void)?

    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "moga.tcp")

    func connect(host: String, port: UInt16 = 2050) {
        state = .connecting
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!
        )
        let conn = NWConnection(to: endpoint, using: .tcp)
        connection = conn

        conn.stateUpdateHandler = { [weak self] newState in
            DispatchQueue.main.async {
                switch newState {
                case .ready:
                    self?.state = .connected
                    self?.receiveHeader()
                case .failed(let error):
                    self?.state = .failed(error)
                case .cancelled:
                    self?.state = .disconnected
                default:
                    break
                }
            }
        }

        conn.start(queue: queue)
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
    }

    func send(type: PacketType, payload: Data = Data()) {
        let header = PacketHeader(type: type, length: UInt32(payload.count))
        var packet = header.encode()
        packet.append(payload)
        connection?.send(content: packet, completion: .idempotent)
    }

    // MARK: - Receive loop

    private func receiveHeader() {
        connection?.receive(minimumIncompleteLength: PacketHeader.size,
                            maximumLength: PacketHeader.size) { [weak self] data, _, _, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async { self.state = .failed(error) }
                return
            }
            guard let data, let header = PacketHeader.decode(from: data) else { return }

            if header.length > 0 {
                self.receivePayload(header: header)
            } else {
                DispatchQueue.main.async { self.onPacket?(header.type, Data()) }
                self.receiveHeader()
            }
        }
    }

    private func receivePayload(header: PacketHeader) {
        let length = Int(header.length)
        connection?.receive(minimumIncompleteLength: length,
                            maximumLength: length) { [weak self] data, _, _, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async { self.state = .failed(error) }
                return
            }
            let payload = data ?? Data()
            DispatchQueue.main.async { self.onPacket?(header.type, payload) }
            self.receiveHeader()
        }
    }
}
