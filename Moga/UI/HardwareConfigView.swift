import SwiftUI

struct HardwareConfigView: View {
    let config: HardwareConfig

    var body: some View {
        Form {
            Section("Device") {
                Picker("Hardware Type", selection: Binding(
                    get: { config.hardwareType },
                    set: { config.hardwareType = $0 }
                )) {
                    ForEach(HardwareType.allCases, id: \.self) { Text($0.rawValue) }
                }
                Picker("Controller", selection: Binding(
                    get: { config.controllerType },
                    set: { config.controllerType = $0 }
                )) {
                    ForEach(ControllerType.allCases, id: \.self) { Text($0.rawValue) }
                }
                Picker("Shield", selection: Binding(
                    get: { config.shieldType },
                    set: { config.shieldType = $0 }
                )) {
                    ForEach(ShieldType.allCases, id: \.self) { Text($0.rawValue) }
                }
                Picker("Camera", selection: Binding(
                    get: { config.cameraType },
                    set: { config.cameraType = $0 }
                )) {
                    ForEach(CameraType.allCases, id: \.self) { Text($0.rawValue) }
                }
            }

            Section("Network") {
                TextField("Hostname", text: Binding(
                    get: { config.hostname },
                    set: { config.hostname = $0 }
                ))
                HStack {
                    Text("Port")
                    Spacer()
                    Text("\(config.port)")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Save Configuration") { config.save() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle("Hardware Configuration")
    }
}
