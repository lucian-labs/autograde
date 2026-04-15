import SwiftUI
import UniformTypeIdentifiers

struct ResizeView: View {
    @ObservedObject var vm: AutoGradeViewModel
    @State private var items: [ResizeItem] = []
    @State private var selectedSize: AppStoreSize? = nil   // nil = auto
    @State private var isTargeted = false
    @State private var statusMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 200, maximum: 260), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            resizeToolbar
            Divider().opacity(0.3)

            if items.isEmpty {
                dropZone
            } else {
                grid
            }
        }
        .onDrop(of: [.fileURL, .image], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
        .overlay(
            Group {
                if isTargeted {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6]))
                        .background(Color.accentColor.opacity(0.06).clipShape(RoundedRectangle(cornerRadius: 12)))
                        .padding(8)
                        .allowsHitTesting(false)
                }
            }
        )
    }

    // MARK: Toolbar

    private var resizeToolbar: some View {
        HStack(spacing: 10) {
            Text("resize")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))

            Spacer()

            if let msg = statusMessage {
                Text(msg)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }

            // Size picker — nil = auto-detect
            Picker("", selection: $selectedSize) {
                Text("Auto").tag(Optional<AppStoreSize>.none)
                Divider()
                ForEach(AppStoreSize.allCases) { size in
                    Text(size.rawValue).tag(Optional(size))
                }
            }
            .pickerStyle(.menu)
            .frame(width: 200)
            .help("Target size — Auto picks nearest match per image")

            if !items.isEmpty {
                Button("Export All") { exportAll() }
                    .buttonStyle(ToolbarButtonStyle(accent: true))

                Button(action: { items.removeAll() }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(ToolbarButtonStyle())
            }

            Button(action: {
                if let folder = ExportManager.chooseOutputFolder() {
                    vm.outputFolder = folder
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                    Text(vm.outputFolder?.lastPathComponent ?? "Set Folder")
                        .lineLimit(1)
                }
                .font(.system(size: 11))
            }
            .buttonStyle(ToolbarButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: Drop zone

    private var dropZone: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("Drop screenshots to resize")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Auto-fits to nearest App Store submission size")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)

            // Size reference
            VStack(spacing: 4) {
                ForEach(AppStoreSize.allCases) { size in
                    Text(size.rawValue)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.quaternary)
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    // MARK: Grid

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(items) { item in
                    ResizeCard(item: item) {
                        exportSingle(item)
                    } onRemove: {
                        items.removeAll { $0.id == item.id }
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: Drop handling

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let path = String(data: data, encoding: .utf8),
                      let url = URL(string: path) else { return }
                let ext = url.pathExtension.lowercased()
                guard ["jpg","jpeg","png","heic","tiff","webp"].contains(ext) else { return }
                Task { @MainActor in addItem(url: url) }
            }
        }
        return true
    }

    private func addItem(url: URL) {
        guard !items.contains(where: { $0.url == url }) else { return }
        let item = ResizeItem(url: url)
        items.append(item)
        Task { await processItem(item) }
    }

    private func processItem(_ item: ResizeItem) async {
        guard let original = NSImage(contentsOf: item.url) else { return }
        let target = selectedSize ?? AppStoreSize.nearest(for: original.size)
        await MainActor.run { item.targetSize = target; item.state = .processing }
        let resized = await ResizeProcessor.shared.resize(image: original, to: target)
        await MainActor.run {
            item.resized = resized
            item.state = resized != nil ? .done : .failed
        }
    }

    // MARK: Export

    private func exportAll() {
        guard let folder = vm.outputFolder ?? ExportManager.chooseOutputFolder() else { return }
        vm.outputFolder = folder
        Task {
            var count = 0
            for item in items where item.resized != nil {
                if let _ = try? await ResizeProcessor.shared.exportResized(
                    item.resized!, originalURL: item.url,
                    size: item.targetSize ?? .iphone67Portrait, to: folder
                ) { count += 1 }
            }
            await show("Exported \(count) file\(count == 1 ? "" : "s")")
        }
    }

    private func exportSingle(_ item: ResizeItem) {
        guard let img = item.resized,
              let target = item.targetSize,
              let folder = vm.outputFolder ?? ExportManager.chooseOutputFolder() else { return }
        vm.outputFolder = folder
        Task {
            if let _ = try? await ResizeProcessor.shared.exportResized(img, originalURL: item.url, size: target, to: folder) {
                await show("Saved")
            }
        }
    }

    private func show(_ msg: String) async {
        await MainActor.run { statusMessage = msg }
        try? await Task.sleep(nanoseconds: 2_500_000_000)
        await MainActor.run { statusMessage = nil }
    }
}

// MARK: - ResizeItem model

@MainActor
class ResizeItem: ObservableObject, Identifiable {
    let id = UUID()
    let url: URL
    @Published var resized: NSImage?
    @Published var targetSize: AppStoreSize?
    @Published var state: RState = .idle

    enum RState { case idle, processing, done, failed }

    var displayName: String { url.lastPathComponent }

    init(url: URL) { self.url = url }
}

// MARK: - ResizeCard

struct ResizeCard: View {
    @ObservedObject var item: ResizeItem
    var onExport: () -> Void
    var onRemove: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 0) {
            // Preview
            ZStack(alignment: .topTrailing) {
                Group {
                    if let img = item.resized {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                item.state == .processing
                                    ? AnyView(ProgressView().controlSize(.small))
                                    : AnyView(Image(systemName: "photo").foregroundStyle(.tertiary))
                            )
                    }
                }
                .frame(width: 200, height: 160)
                .clipped()

                // Remove
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 18, height: 18)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .opacity(hovering ? 1 : 0)
                .padding(6)
            }

            // Info + action
            VStack(spacing: 5) {
                Text(item.displayName)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let size = item.targetSize {
                    Text(size.rawValue)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack {
                    if case .done = item.state {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 12))
                    } else if case .failed = item.state {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 12))
                    }
                    Spacer()
                    Button(action: onExport) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .buttonStyle(ChipButtonStyle())
                    .disabled(item.resized == nil)
                }
            }
            .padding(10)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
        .onHover { hovering = $0 }
    }
}
