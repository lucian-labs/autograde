import Foundation
import AppKit
import AVFoundation

enum MediaType {
    case image, video
}

enum ProcessingState {
    case idle, processing, done, failed(String)
}

@MainActor
class MediaItem: ObservableObject, Identifiable {
    let id = UUID()
    let url: URL
    let type: MediaType

    @Published var thumbnail: NSImage?
    @Published var processedImage: NSImage?
    @Published var settings: EditSettings = .autoMode
    @Published var state: ProcessingState = .idle
    @Published var showOriginal: Bool = false

    var displayName: String { url.lastPathComponent }

    var previewImage: NSImage? {
        showOriginal ? thumbnail : (processedImage ?? thumbnail)
    }

    init(url: URL) {
        self.url = url
        let ext = url.pathExtension.lowercased()
        self.type = ["mp4", "mov", "m4v", "avi", "mkv"].contains(ext) ? .video : .image
    }

    func loadThumbnail() async {
        switch type {
        case .image:
            if let img = NSImage(contentsOf: url) {
                thumbnail = img.resized(toMaxDimension: 600)
            }
        case .video:
            let asset = AVURLAsset(url: url)
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = CGSize(width: 600, height: 600)
            if let cgImg = try? await gen.image(at: .zero).image {
                thumbnail = NSImage(cgImage: cgImg, size: .zero)
            }
        }
    }
}

private extension NSImage {
    func resized(toMaxDimension max: CGFloat) -> NSImage {
        let aspect = size.width / size.height
        let newSize: CGSize = size.width >= size.height
            ? CGSize(width: max, height: max / aspect)
            : CGSize(width: max * aspect, height: max)
        let img = NSImage(size: newSize)
        img.lockFocus()
        draw(in: NSRect(origin: .zero, size: newSize),
             from: NSRect(origin: .zero, size: size),
             operation: .copy, fraction: 1)
        img.unlockFocus()
        return img
    }
}
