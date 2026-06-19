import SwiftUI

struct SettingsView: View {
    @AppStorage("apiKey")        private var apiKey: String = ""
    @AppStorage("autoConnect")   private var autoConnect: Bool = false
    @AppStorage("defaultPattern") private var defaultPattern: String = ScanPattern.fibonacci.rawValue

    var body: some View {
        Form {
            Section("OpenScan Cloud") {
                SecureField("API Key", text: $apiKey)
                Text("Your API key is available from openscan.eu after registering.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Connection") {
                Toggle("Auto-connect on launch", isOn: $autoConnect)
            }

            Section("Defaults") {
                Picker("Default Scan Pattern", selection: $defaultPattern) {
                    ForEach(ScanPattern.allCases, id: \.rawValue) {
                        Text($0.rawValue).tag($0.rawValue)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 420, height: 300)
        .navigationTitle("Settings")
    }
}
