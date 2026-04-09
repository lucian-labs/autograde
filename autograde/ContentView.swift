import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var vm = AutoGradeViewModel()
    @State private var isTargeted = false

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 12)]

    var body: some View {
        ZStack {
            Color(nsColor: .controlBackgroundColor).ignoresSafeArea()

            VStack(spacing: 0) {
                toolbar
                Divider().opacity(0.3)
                content
            }
        }
        .onDrop(of: vm.supportedTypes, isTargeted: $isTargeted) { providers in
            vm.handleDrop(providers: providers)
        }
        .overlay(dropOverlay)
        .animation(.easeInOut(duration: 0.15), value: isTargeted)
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 10) {
            // App name
            Text("autograde")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)

            Spacer()

            if let msg = vm.exportMessage {
                Text(msg)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }

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

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if vm.items.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(vm.items) { item in
                        MediaCard(
                            item: item,
                            onRemove: { vm.removeItem(item) },
                            onExport: { vm.exportItem(item) },
                            onReprocess: { vm.processItem(item) }
                        )
                    }
                }
                .padding(16)
            }
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
