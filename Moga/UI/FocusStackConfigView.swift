import SwiftUI

struct FocusStackConfigView: View {
    let config: FocusStackConfig

    var body: some View {
        GroupBox("Focus Stacking") {
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Enable Focus Stacking", isOn: Binding(
                    get: { config.enabled },
                    set: { config.enabled = $0 }
                ))
                .font(.headline)

                if config.enabled {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Near Focus: \(config.nearDiopters, specifier: "%.1f") diopters")
                                .font(.subheadline)
                            Slider(value: Binding(
                                get: { config.nearDiopters },
                                set: { config.nearDiopters = $0 }
                            ), in: 0.5...10.0, step: 0.1)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Far Focus: \(config.farDiopters, specifier: "%.1f") diopters")
                                .font(.subheadline)
                            Slider(value: Binding(
                                get: { config.farDiopters },
                                set: { config.farDiopters = $0 }
                            ), in: 0.0...9.5, step: 0.1)
                        }

                        Stepper(
                            "Stack Size: \(config.clampedStackSize) frames",
                            value: Binding(
                                get: { config.stackSize },
                                set: { config.stackSize = $0 }
                            ),
                            in: 2...20
                        )
                        .font(.subheadline)

                        Text("Captures \(config.clampedStackSize) images per position between \(config.farDiopters, specifier: "%.1f")–\(config.nearDiopters, specifier: "%.1f") diopters.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity)
                }
            }
            .padding(8)
            .animation(.easeInOut(duration: 0.2), value: config.enabled)
        }
    }
}
