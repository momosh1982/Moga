import SwiftUI

struct ScanView: View {
    let session: DeviceSession
    let focusConfig: FocusStackConfig
    let projectManager: ProjectManager

    @State private var selectedPattern: ScanPattern = .fibonacci
    @State private var photoCount: Int = 100
    @State private var projectName: String = ""
    @State private var controller: ScanController? = nil
    @State private var currentProject: MogaProject? = nil
    @State private var progress: Double = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("New Scan").font(.title2).bold()

                // Project name
                GroupBox("Project") {
                    TextField("Project name", text: $projectName)
                        .textFieldStyle(.roundedBorder)
                }

                // Scan pattern
                GroupBox("Scan Pattern") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Pattern", selection: $selectedPattern) {
                            ForEach(ScanPattern.allCases, id: \.self) { Text($0.rawValue) }
                        }
                        .pickerStyle(.segmented)

                        Stepper("Photos: \(photoCount)", value: $photoCount, in: 10...500, step: 10)
                    }
                    .padding(4)
                }

                // Focus stacking
                FocusStackConfigView(config: focusConfig)

                // Light control
                GroupBox("Lighting") {
                    HStack {
                        Text("Ring Light")
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { session.isLightOn },
                            set: { session.setLight(on: $0) }
                        ))
                    }
                    .padding(4)
                }

                // Scan progress
                if let ctrl = controller {
                    GroupBox("Progress") {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView(value: progress)
                            Text("\(ctrl.currentPositionIndex) / \(ctrl.totalPositions) positions")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(4)
                    }
                }

                // Start button
                HStack {
                    Spacer()
                    Button(controller == nil ? "Start Scan" : "Cancel") {
                        controller == nil ? startScan() : cancelScan()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(controller == nil ? .accentColor : .red)
                    .disabled(projectName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(24)
        }
    }

    private func startScan() {
        guard let project = try? projectManager.createProject(
            name: projectName.trimmingCharacters(in: .whitespaces),
            photoCount: photoCount,
            pattern: selectedPattern.rawValue,
            focusStack: focusConfig.enabled,
            stackSize: focusConfig.clampedStackSize
        ) else { return }

        currentProject = project
        let ctrl = ScanController(session: session, focusConfig: focusConfig)
        ctrl.onBundleComplete = { posIndex, images in
            progress = Double(posIndex + 1) / Double(photoCount)
            for (stackIndex, data) in images.enumerated() {
                try? projectManager.savePhoto(data, project: project,
                                              positionIndex: posIndex, stackIndex: stackIndex)
            }
        }
        controller = ctrl
        ctrl.start(pattern: selectedPattern, photoCount: photoCount)
    }

    private func cancelScan() {
        controller?.cancel()
        controller = nil
        progress = 0
    }
}
