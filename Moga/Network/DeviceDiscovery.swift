import Foundation
import Network

// Listens on UDP port 1981 for OpenScan device broadcast announcements.
// Magic identifier: 0x4E43534F ("NCSO")
// Broadcast packet: 6 bytes — 4-byte magic + 2-byte TCP port

struct DiscoveredDevice: Identifiable, Equatable {
    let id = UUID()
    let host: String
    let port: UInt16
}

@Observable
final class DeviceDiscovery {
    private(set) var devices: [DiscoveredDevice] = []
    private var listener: NWListener?

    private let magic: UInt32 = 0x4E43534F
    private let udpPort: NWEndpoint.Port = 1981

    func start() {
        guard listener == nil else { return }
        do {
            listener = try NWListener(using: .udp, on: udpPort)
        } catch {
            print("DeviceDiscovery: failed to create listener — \(error)")
            return
        }

        listener?.newConnectionHandler = { [weak self] connection in
            connection.start(queue: .global())
            self?.receive(on: connection)
        }

        listener?.start(queue: .global())
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, context, _, error in
            if let data, data.count >= 6 {
                self?.handleBroadcast(data: data, connection: connection)
            }
        }
    }

    private func handleBroadcast(data: Data, connection: NWConnection) {
        let receivedMagic = data.readUInt32(at: 0)
        guard receivedMagic == magic else { return }

        let tcpPort = data.readUInt16(at: 4)

        guard let endpoint = connection.currentPath?.remoteEndpoint,
              case let .hostPort(host, _) = endpoint else { return }

        let hostString = "\(host)"
        let device = DiscoveredDevice(host: hostString, port: tcpPort)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if !devices.contains(device) {
                devices.append(device)
            }
        }
    }
}
