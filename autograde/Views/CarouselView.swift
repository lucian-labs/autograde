import SwiftUI
import AppKit

struct CarouselView: View {
    let folderURL: URL?
    @Binding var selectedURL: URL?

    @State private var images: [FolderImage] = []
    @State private var watcher: DirectoryWatcher?

    var body: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.3)

            if images.isEmpty {
                emptyStrip
            } else {
                strip
            }
        }
        .frame(height: 104)
        .background(.ultraThinMaterial)
        .onChange(of: folderURL) { _, url in reload(url) }
        .onAppear { reload(folderURL) }
    }

    // MARK: Strip

    private var strip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(images) { img in
                        FolderThumb(image: img, isSelected: selectedURL == img.url)
                            .id(img.url)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedURL = img.url
                                }
                            }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .onChange(of: selectedURL) { _, url in
                guard let url else { return }
                withAnimation { proxy.scrollTo(url, anchor: .center) }
            }
        }
    }

    private var emptyStrip: some View {
        HStack {
            Spacer()
            Text(folderURL == nil ? "Set an output folder to browse images" : "No images in folder yet")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: Load

    private func reload(_ url: URL?) {
        watcher = nil
        guard let url else { images = []; return }

        loadImages(from: url)

        // Watch for new files (exports land here in real time)
        watcher = DirectoryWatcher(url: url) { reload(url) }
    }

    private func loadImages(from url: URL) {
        let exts = Set(["jpg","jpeg","png","heic","tiff","gif","webp","mov","mp4","m4v"])
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let filtered = entries
            .filter { exts.contains($0.pathExtension.lowercased()) }
            .sorted {
                let d0 = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let d1 = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return d0 > d1  // newest first
            }
            .map { FolderImage(url: $0) }

        DispatchQueue.main.async { images = filtered }
    }
}

// MARK: - Thumbnail cell

private struct FolderThumb: View {
    let image: FolderImage
    let isSelected: Bool
    @State private var thumb: NSImage?
    @State private var hovering = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let t = thumb {
                    Image(nsImage: t)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .overlay(ProgressView().controlSize(.mini))
                }
            }
            .frame(width: thumbWidth, height: 72)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 5))

            if isVideo {
                Image(systemName: "film")
                    .font(.system(size: 8, weight: .semibold))
                    .padding(3)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 3))
                    .padding(3)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.white.opacity(hovering ? 0.18 : 0.06),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .scaleEffect(isSelected ? 1.06 : (hovering ? 1.02 : 1.0))
        .animation(.spring(duration: 0.18), value: isSelected)
        .onHover { hovering = $0 }
        .task { await loadThumb() }
        .help(image.url.lastPathComponent)
    }

    private var isVideo: Bool {
        ["mov","mp4","m4v"].contains(image.url.pathExtension.lowercased())
    }

    private var thumbWidth: CGFloat {
        guard let t = thumb else { return 72 }
        let a = t.size.width / t.size.height
        return min(max(a * 72, 48), 140)
    }

    private func loadThumb() async {
        guard thumb == nil else { return }
        thumb = await ThumbnailLoader.load(url: image.url)
    }
}

// MARK: - Models

struct FolderImage: Identifiable, Equatable {
    let url: URL
    var id: URL { url }
}

// MARK: - Async thumbnail loader

enum ThumbnailLoader {
    static func load(url: URL) async -> NSImage? {
        await Task.detached(priority: .utility) {
            let ext = url.pathExtension.lowercased()
            if ["mov","mp4","m4v"].contains(ext) {
                return videoThumb(url: url)
            }
            guard let img = NSImage(contentsOf: url) else { return nil }
            return resized(img, maxDim: 300)
        }.value
    }

    private static func videoThumb(url: URL) -> NSImage? {
        let asset = AVURLAssetShim(url: url)
        let gen = AVAssetImageGeneratorShim(asset: asset)
        return gen.firstFrame()
    }

    private static func resized(_ img: NSImage, maxDim: CGFloat) -> NSImage {
        let s = img.size
        let scale = min(maxDim / s.width, maxDim / s.height)
        let newSize = CGSize(width: s.width * scale, height: s.height * scale)
        let out = NSImage(size: newSize)
        out.lockFocus()
        img.draw(in: NSRect(origin: .zero, size: newSize))
        out.unlockFocus()
        return out
    }
}

// Thin shims to avoid importing AVFoundation at top level
import AVFoundation

private struct AVURLAssetShim { let url: URL }
private struct AVAssetImageGeneratorShim {
    let asset: AVURLAssetShim
    func firstFrame() -> NSImage? {
        let a = AVURLAsset(url: asset.url)
        let gen = AVAssetImageGenerator(asset: a)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 300, height: 300)
        guard let cg = try? gen.copyCGImage(at: .zero, actualTime: nil) else { return nil }
        return NSImage(cgImage: cg, size: .zero)
    }
}

// MARK: - Directory watcher

final class DirectoryWatcher {
    private var source: DispatchSourceFileSystemObject?

    init(url: URL, onChange: @escaping () -> Void) {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .global(qos: .utility)
        )
        src.setEventHandler {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onChange() }
        }
        src.setCancelHandler { close(fd) }
        src.resume()
        source = src
    }

    deinit { source?.cancel() }
}
