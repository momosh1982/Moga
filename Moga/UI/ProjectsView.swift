import SwiftUI

struct ProjectsView: View {
    let projectManager: ProjectManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Projects").font(.title2).bold().padding(24)

            if projectManager.projects.isEmpty {
                ContentUnavailableView(
                    "No Projects Yet",
                    systemImage: "folder.badge.plus",
                    description: Text("Start a scan to create your first project.")
                )
            } else {
                List(projectManager.projects) { project in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(project.name).font(.headline)
                            Text("\(project.photoCount) photos · \(project.patternName)" +
                                 (project.focusStackEnabled ? " · Focus stack ×\(project.stackSize)" : ""))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(project.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Button("Open Folder") {
                            projectManager.openProjectFolder(project)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
        .onAppear { projectManager.loadProjects() }
    }
}
