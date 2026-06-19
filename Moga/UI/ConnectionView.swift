import SwiftUI

struct ConnectionView: View {
    let config: HardwareConfig
    @Binding var session: DeviceSession?

    @State private var discovery = DeviceDiscovery()
    @State private var isConnecting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Text("Connect to OpenScan")
                .font(.title2).bold()

            // Discovered devices
            if discovery.devices.isEmpty {
                HStack {
                    ProgressView().scaleEffect(0.7)
                    Text("Scanning network for devices…")
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Discovered Devices").font(.headline)
                    ForEach(discovery.devices) { device in
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                            Text("\(device.host) : \(device.port)")
                            Spacer()
                            Button("Connect") { connect(to: device) }
                                .disabled(isConnecting)
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
                    }
                }
            }

            Divider()

            // Manual connection
            VStack(alignment: .leading, spacing: 8) {
                Text("Manual Connection").font(.headline)
                HStack {
                    Text("Host:")
                    TextField("openscan.local", text: Binding(
                        get: { config.hostname },
                        set: { config.hostname = $0 }
                    ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 220)
                }
                Button(isConnecting ? "Connecting…" : "Connect") {
                    connectManual()
                }
                .disabled(isConnecting)
                .buttonStyle(.borderedProminent)
            }

            if let error = errorMessage {
                Text(error).foregroundStyle(.red).font(.caption)
            }

            if session != nil {
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Button("Disconnect", role: .destructive) { disconnect() }
            }
        }
        .padding(32)
        .onAppear { discovery.start() }
        .onDisappear { discovery.stop() }
    }

    private func connect(to device: DiscoveredDevice) {
        config.hostname = device.host
        config.port = device.port
        connectManual()
    }

    private func connectManual() {
        isConnecting = true
        errorMessage = nil
        let s = DeviceSession(config: config)
        s.connect()
        // Poll for connection result
        Task {
            try? await Task.sleep(for: .seconds(5))
            await MainActor.run {
                isConnecting = false
                switch s.state {
                case .ready:
                    session = s
                case .failed(let msg):
                    errorMessage = msg
                default:
                    errorMessage = "Connection timed out."
                }
            }
        }
    }

    private func disconnect() {
        session?.disconnect()
        session = nil
    }
}
