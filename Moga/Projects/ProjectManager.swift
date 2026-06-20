import Foundation
import AppKit

struct MogaProject: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var folderName: String      // name + timestamp, e.g. "MyObject_20260620_1430"
    let createdAt: Date
    var photoCount: Int
    var patternName: String
    var focusStackEnabled: Bool
    var stackSize: Int
    var baseURL: URL?           // nil = default Documents/Moga Projects
}

@Observable
final class ProjectManager {
    private(set) var projects: [MogaProject] = []

    private var defaultRootURL: URL {
        URL.documentsDirectory.appendingPathComponent("Moga Projects", isDirectory: true)
    }

    func projectURL(_ project: MogaProject) -> URL {
        let base = project.baseURL ?? defaultRootURL
        return base.appendingPathComponent(project.folderName, isDirectory: true)
    }

    func photosURL(_ project: MogaProject) -> URL {
        projectURL(project).appendingPathComponent("Photos", isDirectory: true)
    }

    // MARK: - Create

    private static let folderDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmm"
        return f
    }()

    func createProject(name: String, photoCount: Int, pattern: String,
                       focusStack: Bool, stackSize: Int,
                       outputFolder: URL? = nil) throws -> MogaProject {
        let timestamp = Self.folderDateFormatter.string(from: Date())
        let folderName = "\(name)_\(timestamp)"
        let project = MogaProject(
            id: UUID(), name: name, folderName: folderName, createdAt: Date(),
            photoCount: photoCount, patternName: pattern,
            focusStackEnabled: focusStack, stackSize: stackSize,
            baseURL: outputFolder
        )
        let photosDir = photosURL(project)
        try FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)
        try saveMetadata(project)
        projects.append(project)
        return project
    }

    // MARK: - Save photos

    func savePhoto(_ data: Data, project: MogaProject, positionIndex: Int, stackIndex: Int) throws {
        let filename = String(format: "photo_%04d_%02d.jpg", positionIndex, stackIndex)
        let url = photosURL(project).appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
    }

    func saveMergedPhoto(_ data: Data, project: MogaProject, positionIndex: Int) throws {
        let filename = String(format: "merged_%04d.jpg", positionIndex)
        let url = photosURL(project).appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Zip

    func zipProject(_ project: MogaProject) async throws -> URL {
        let sourceURL = photosURL(project)
        let zipURL = projectURL(project).appendingPathComponent("\(project.name).zip")
        await Task.detached(priority: .utility) {
            let coordinator = NSFileCoordinator()
            var error: NSError?
            coordinator.coordinate(readingItemAt: sourceURL, options: .forUploading, error: &error) { url in
                try? FileManager.default.copyItem(at: url, to: zipURL)
            }
        }.value
        return zipURL
    }

    // MARK: - Load projects from disk

    func loadProjects() {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: defaultRootURL, includingPropertiesForKeys: nil) else { return }
        let decoder = JSONDecoder()
        projects = contents.compactMap { url -> MogaProject? in
            let metaURL = url.appendingPathComponent("project.json")
            guard let data = try? Data(contentsOf: metaURL) else { return nil }
            if var project = try? decoder.decode(MogaProject.self, from: data) {
                return project
            }
            // Legacy projects saved before folderName was added — synthesise it from the folder name on disk
            if var legacy = try? decoder.decode(LegacyMogaProject.self, from: data) {
                return MogaProject(id: legacy.id, name: legacy.name,
                                   folderName: url.lastPathComponent,
                                   createdAt: legacy.createdAt, photoCount: legacy.photoCount,
                                   patternName: legacy.patternName,
                                   focusStackEnabled: legacy.focusStackEnabled,
                                   stackSize: legacy.stackSize, baseURL: nil)
            }
            return nil
        }.sorted { $0.createdAt > $1.createdAt }
    }

    private struct LegacyMogaProject: Decodable {
        let id: UUID; var name: String; let createdAt: Date
        var photoCount: Int; var patternName: String
        var focusStackEnabled: Bool; var stackSize: Int
    }

    func openProjectFolder(_ project: MogaProject) {
        NSWorkspace.shared.open(projectURL(project))
    }

    // MARK: - Private

    private func saveMetadata(_ project: MogaProject) throws {
        let data = try JSONEncoder().encode(project)
        try data.write(to: projectURL(project).appendingPathComponent("project.json"), options: .atomic)
    }
}
