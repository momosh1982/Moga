import SwiftUI

struct MainWindowView: View {
    @State private var config = HardwareConfig.load()
    @State private var session: DeviceSession? = nil
    @State private var focusConfig = FocusStackConfig()
    @State private var projectManager = ProjectManager()
    @State private var selection: SidebarItem = .connect

    enum SidebarItem: String, CaseIterable, Identifiable {
        case connect      = "Connect"
        case hardware     = "Hardware"
        case scan         = "Scan"
        case postprocess  = "Post-Process"
        case projects     = "Projects"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .connect:     return "wifi"
            case .hardware:    return "gearshape"
            case .scan:        return "camera.aperture"
            case .postprocess: return "wand.and.stars"
            case .projects:    return "folder"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(180)
            .listStyle(.sidebar)
        } detail: {
            Group {
                switch selection {
                case .connect:
                    ConnectionView(config: config, session: $session)
                case .hardware:
                    HardwareConfigView(config: config)
                case .scan:
                    if let session {
                        ScanView(session: session,
                                 focusConfig: focusConfig,
                                 projectManager: projectManager)
                    } else {
                        notConnectedPlaceholder
                    }
                case .postprocess:
                    PostProcessingView(projectManager: projectManager)
                case .projects:
                    ProjectsView(projectManager: projectManager)
                }
            }
            .frame(minWidth: 600, minHeight: 400)
        }
        .onAppear { projectManager.loadProjects() }
    }

    private var notConnectedPlaceholder: some View {
        ContentUnavailableView(
            "Not Connected",
            systemImage: "wifi.slash",
            description: Text("Connect to your OpenScan device first.")
        )
    }
}
