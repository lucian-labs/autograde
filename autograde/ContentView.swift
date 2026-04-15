import SwiftUI
import UniformTypeIdentifiers

enum AppTab { case grade, resize }

struct ContentView: View {
    @ObservedObject var vm: AutoGradeViewModel
    @EnvironmentObject var screenshotManager: ScreenshotManager
    @State private var isTargeted = false
    @State private var selectedID: UUID?
    @State private var selectedFolderURL: URL?
    @State private var activeTab: AppTab = .grade

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 12)]

    var body: some View {
        ZStack {
            Color(nsColor: .controlBackgroundColor).ignoresSafeArea()

            VStack(spacing: 0) {
                tabBar
                Divider().opacity(0.3)
                tabContent
            }
        }
        .onDrop(of: vm.supportedTypes, isTargeted: $isTargeted) { providers in
            guard activeTab == .grade else { return false }
            return vm.handleDrop(providers: providers)
        }
        .overlay(dropOverlay)
        .animation(.easeInOut(duration: 0.15), value: isTargeted)
    }

    // MARK: Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            TabButton(label: "grade",  icon: "wand.and.stars",  tab: .grade,  active: activeTab) { activeTab = .grade }
            TabButton(label: "resize", icon: "arrow.up.left.and.arrow.down.right", tab: .resize, active: activeTab) { activeTab = .resize }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch activeTab {
        case .grade:  gradeContent
        case .resize: ResizeView(vm: vm)
        }
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 10) {
            // App name
            Text("autograde")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)

            Spacer()

            if let msg = screenshotManager.statusMessage ?? vm.exportMessage {
                Text(msg)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }

            // Screenshot capture button
            Button(action: {
                Task { @MainActor in
                    await screenshotManager.capture(
                        settings: vm.screenshotSettings,
                        outputFolder: vm.outputFolder
                    )
                }
            }) {
                Image(systemName: "camera.viewfinder")
            }
            .buttonStyle(ToolbarButtonStyle())
            .help("Screenshot ⌘⇧G")

            if !vm.items.isEmpty {
                Button("Auto All") { vm.applyAutoAll() }
                    .buttonStyle(ToolbarButtonStyle(accent: false))

                Button("Export All") { vm.exportAll() }
                    .buttonStyle(ToolbarButtonStyle(accent: true))
                    .disabled(vm.isExporting)

                Button(action: { vm.items.removeAll() }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(ToolbarButtonStyle())
                .help("Clear all")
            }

            // Output folder indicator
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
            .help(vm.outputFolder?.path ?? "Choose export destination")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: Grade content

    @ViewBuilder
    private var gradeContent: some View {
        VStack(spacing: 0) {
            if vm.items.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(vm.items) { item in
                                MediaCard(
                                    item: item,
                                    onRemove: { vm.removeItem(item) },
                                    onExport: { vm.exportItem(item) },
                                    onReprocess: { vm.processItem(item) }
                                )
                                .id(item.id)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Color.accentColor, lineWidth: 2)
                                        .opacity(selectedID == item.id ? 1 : 0)
                                )
                                .onTapGesture { selectedID = item.id }
                                .onChange(of: vm.items.count) { _, _ in
                                    if !vm.items.contains(where: { $0.id == selectedID }) { selectedID = nil }
                                }
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: selectedID) { _, id in
                        guard let id else { return }
                        withAnimation { proxy.scrollTo(id, anchor: .center) }
                    }
                }
            }

            // Always-visible folder carousel
            CarouselView(folderURL: vm.outputFolder, selectedURL: $selectedFolderURL)
        }
    }

    // MARK: Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.stack")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Drop photos or videos")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Auto mode applies exposure, grain, and watermark on drop")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    // MARK: Drop Overlay

    @ViewBuilder
    private var dropOverlay: some View {
        if isTargeted {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6]))
                .background(Color.accentColor.opacity(0.06).clipShape(RoundedRectangle(cornerRadius: 12)))
                .padding(8)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let label: String
    let icon: String
    let tab: AppTab
    let active: AppTab
    let action: () -> Void

    var isActive: Bool { tab == active }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11))
                Text(label).font(.system(size: 12, weight: .medium, design: .monospaced))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isActive ? Color.primary.opacity(0.1) : .clear)
            .foregroundStyle(isActive ? .primary : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Toolbar Button Style

struct ToolbarButtonStyle: ButtonStyle {
    var accent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(accent ? Color.accentColor : Color.primary.opacity(0.07))
            .foregroundStyle(accent ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
