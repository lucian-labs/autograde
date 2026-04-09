import SwiftUI
import UniformTypeIdentifiers

@MainActor
class AutoGradeViewModel: ObservableObject {
    @Published var items: [MediaItem] = []
    @Published var outputFolder: URL?
    @Published var isExporting = false
    @Published var exportMessage: String?
    @Published var globalSettings: EditSettings = .autoMode
    @Published var screenshotSettings: EditSettings = .autoMode

    var supportedTypes: [UTType] { [.image, .movie, .fileURL] }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    guard let data = item as? Data,
                          let path = String(data: data, encoding: .utf8),
                          let url = URL(string: path) else { return }
                    Task { @MainActor in self.addItem(url: url) }
                }
            }
        }
        return true
    }

    func addItem(url: URL) {
        guard !items.contains(where: { $0.url == url }) else { return }
        let item = MediaItem(url: url)
        item.settings = globalSettings
        items.append(item)
        Task { await loadAndProcess(item: item) }
    }

    func removeItem(_ item: MediaItem) {
        items.removeAll { $0.id == item.id }
    }

    func applyAutoAll() {
        for item in items {
            item.settings = .autoMode
        }
        Task {
            for item in items {
                await loadAndProcess(item: item)
            }
        }
    }

    func exportAll() {
        guard let folder = outputFolder ?? pickFolder() else { return }
        outputFolder = folder
        isExporting = true
        Task {
            var exported = 0
            var failed = 0
            for item in items {
                do {
                    try await exportItem(item, to: folder)
                    exported += 1
                } catch {
                    failed += 1
                }
            }
            isExporting = false
            exportMessage = failed == 0
                ? "Exported \(exported) file\(exported == 1 ? "" : "s")"
                : "Exported \(exported), failed \(failed)"
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            exportMessage = nil
        }
    }

    func exportItem(_ item: MediaItem) {
        guard let folder = outputFolder ?? pickFolder() else { return }
        outputFolder = folder
        Task {
            try? await exportItem(item, to: folder)
        }
    }

    func processItem(_ item: MediaItem) {
        Task { await loadAndProcess(item: item) }
    }

    // MARK: - Private

    private func loadAndProcess(item: MediaItem) async {
        if item.thumbnail == nil { await item.loadThumbnail() }
        guard item.type == .image, let thumb = item.thumbnail else { return }
        item.state = .processing
        let processed = await ImageProcessor.shared.process(image: thumb, settings: item.settings)
        item.processedImage = processed
        item.state = processed != nil ? .done : .failed("Processing failed")
    }

    private func exportItem(_ item: MediaItem, to folder: URL) async throws {
        switch item.type {
        case .image:
            guard let img = item.processedImage ?? item.thumbnail else { throw ExportError.renderFailed }
            _ = try ExportManager.exportImage(img, originalURL: item.url, to: folder)
        case .video:
            let outURL = ExportManager.videoOutputURL(for: item.url, in: folder)
            try await VideoProcessor.shared.process(url: item.url, settings: item.settings, outputURL: outURL)
        }
    }

    private func pickFolder() -> URL? {
        ExportManager.chooseOutputFolder()
    }
}
