import SwiftUI

struct PostProcessingView: View {
    let projectManager: ProjectManager

    @State private var selectedProject: MogaProject? = nil
    @State private var isProcessing = false
    @State private var statusMessage = ""
    @State private var uploader = CloudUploader()
    @AppStorage("apiKey") private var apiKey: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Post-Processing").font(.title2).bold()

            Picker("Project", selection: $selectedProject) {
                Text("Select a project").tag(Optional<MogaProject>.none)
                ForEach(projectManager.projects) { project in
                    Text(project.name).tag(Optional(project))
                }
            }
            .pickerStyle(.menu)

            if let project = selectedProject {
                GroupBox("Actions") {
                    VStack(alignment: .leading, spacing: 12) {
                        actionButton(
                            title: "Merge Focus Stacks",
                            icon: "square.stack.3d.up",
                            description: "Combine bracketed images into one sharp image per position."
                        ) { await mergeStacks(project: project) }

                        Divider()

                        actionButton(
                            title: "Remove Backgrounds",
                            icon: "person.crop.rectangle",
                            description: "Strip backgrounds from all merged images using Vision."
                        ) { await removeBackgrounds(project: project) }

                        Divider()

                        actionButton(
                            title: "Export for Reality Capture",
                            icon: "square.and.arrow.up",
                            description: "Generate a .rcproj file pointing at this project's photos."
                        ) { exportRC(project: project) }

                        actionButton(
                            title: "Export for Meshroom",
                            icon: "square.and.arrow.up",
                            description: "Generate a .mg file for Meshroom."
                        ) { exportMeshroom(project: project) }

                        Divider()

                        actionButton(
                            title: "Upload to OpenScan Cloud",
                            icon: "icloud.and.arrow.up",
                            description: "Zip and upload photos. Results emailed to your account."
                        ) { await uploadToCloud(project: project) }
                    }
                    .padding(8)
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(24)
        .overlay { if isProcessing { processingOverlay } }
    }

    private func actionButton(title: String, icon: String, description: String,
                               action: @escaping () async -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Label(title, systemImage: icon).font(.headline)
                Text(description).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Run") {
                Task { await action() }
            }
            .disabled(isProcessing)
        }
    }

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
            VStack(spacing: 12) {
                ProgressView()
                Text(statusMessage).foregroundStyle(.white)
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
        }
    }

    private func mergeStacks(project: MogaProject) async {
        isProcessing = true
        statusMessage = "Merging focus stacks…"
        let merger = FocusStackMerger()
        let photosDir = projectManager.photosURL(project)

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: photosDir, includingPropertiesForKeys: nil) else {
            isProcessing = false; return
        }

        // Group by position index
        var byPosition: [Int: [URL]] = [:]
        for file in files where file.lastPathComponent.hasPrefix("photo_") {
            let parts = file.deletingPathExtension().lastPathComponent.split(separator: "_")
            if parts.count >= 2, let pos = Int(parts[1]) {
                byPosition[pos, default: []].append(file)
            }
        }

        for (pos, urls) in byPosition.sorted(by: { $0.key < $1.key }) {
            statusMessage = "Merging position \(pos + 1) of \(byPosition.count)…"
            let images = urls.compactMap { url -> CGImage? in
                guard let data = try? Data(contentsOf: url),
                      let src = CGImageSourceCreateWithData(data as CFData, nil)
                else { return nil }
                return CGImageSourceCreateImageAtIndex(src, 0, nil)
            }
            if let merged = await merger.merge(images),
               let data = cgImageToJPEGData(merged) {
                try? projectManager.saveMergedPhoto(data, project: project, positionIndex: pos)
            }
        }

        statusMessage = "Focus stack merge complete."
        isProcessing = false
    }

    private func removeBackgrounds(project: MogaProject) async {
        isProcessing = true
        statusMessage = "Removing backgrounds…"
        let remover = BackgroundRemoval()
        let photosDir = projectManager.photosURL(project)

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: photosDir, includingPropertiesForKeys: nil) else {
            isProcessing = false; return
        }

        let mergedFiles = files.filter { $0.lastPathComponent.hasPrefix("merged_") }
        for (i, url) in mergedFiles.enumerated() {
            statusMessage = "Processing \(i + 1) of \(mergedFiles.count)…"
            guard let data = try? Data(contentsOf: url),
                  let src = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else { continue }
            let result = await remover.removeBackground(from: image)
            if let outData = cgImageToJPEGData(result) {
                try? outData.write(to: url, options: .atomic)
            }
        }

        statusMessage = "Background removal complete."
        isProcessing = false
    }

    private func exportRC(project: MogaProject) {
        let exporter = RealityCaptureExport()
        if let url = try? exporter.export(project: project,
                                          photosURL: projectManager.photosURL(project)) {
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
            statusMessage = "Reality Capture project saved."
        }
    }

    private func exportMeshroom(project: MogaProject) {
        let exporter = MeshroomExport()
        if let url = try? exporter.export(project: project,
                                          photosURL: projectManager.photosURL(project)) {
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
            statusMessage = "Meshroom project saved."
        }
    }

    private func uploadToCloud(project: MogaProject) async {
        isProcessing = true
        statusMessage = "Zipping project…"
        guard let zipURL = try? await projectManager.zipProject(project) else {
            statusMessage = "Failed to create zip."
            isProcessing = false
            return
        }
        statusMessage = "Uploading to OpenScan Cloud…"
        await uploader.upload(zipURL: zipURL, apiKey: apiKey)
        switch uploader.state {
        case .done:           statusMessage = "Upload complete. Check your email for results."
        case .failed(let m):  statusMessage = m
        default:              break
        }
        isProcessing = false
    }

    private func cgImageToJPEGData(_ image: CGImage) -> Data? {
        let mutableData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(mutableData, "public.jpeg" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary)
        CGImageDestinationFinalize(dest)
        return mutableData as Data
    }
}
