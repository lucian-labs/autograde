import SwiftUI

struct MediaCard: View {
    @ObservedObject var item: MediaItem
    var onRemove: () -> Void
    var onExport: () -> Void
    var onReprocess: () -> Void

    @State private var expanded = false
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 0) {
            thumbnailArea
            controlArea
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.white.opacity(hovering ? 0.12 : 0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
        .onHover { hovering = $0 }
    }

    // MARK: Thumbnail

    private var thumbnailArea: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let img = item.showOriginal ? item.thumbnail : (item.processedImage ?? item.thumbnail) {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .overlay(ProgressView().controlSize(.small))
                }
            }
            .frame(width: 220, height: 160)
            .clipped()

            // Badge
            HStack(spacing: 4) {
                if item.type == .video {
                    Image(systemName: "film")
                        .font(.system(size: 9, weight: .semibold))
                }
                if case .processing = item.state {
                    ProgressView().controlSize(.mini).frame(width: 10, height: 10)
                } else if case .done = item.state {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.green)
                } else if case .failed(let msg) = item.state {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                        .help(msg)
                }
            }
            .padding(5)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
            .padding(6)

            // Remove button
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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onLongPressGesture(minimumDuration: 0) {} onPressingChanged: { pressing in
            item.showOriginal = pressing
        }
    }

    // MARK: Controls

    private var controlArea: some View {
        VStack(spacing: 6) {
            // Filename
            Text(item.displayName)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            if expanded {
                sliders
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Action row
            HStack(spacing: 6) {
                Button("Auto") {
                    item.settings = .autoMode
                    onReprocess()
                }
                .buttonStyle(ChipButtonStyle(accent: true))

                Button(expanded ? "Less" : "Adjust") {
                    withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
                }
                .buttonStyle(ChipButtonStyle())

                Spacer()

                Button(action: onExport) {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(ChipButtonStyle())
                .help("Export this file")
            }
        }
        .padding(10)
    }

    private var sliders: some View {
        VStack(spacing: 5) {
            SliderRow(label: "Exp", value: $item.settings.exposure, range: -2...2) { onReprocess() }
            SliderRow(label: "Grain", value: $item.settings.grain, range: 0...1) { onReprocess() }
            SliderRow(label: "Contrast", value: $item.settings.contrast, range: -1...1) { onReprocess() }
            SliderRow(label: "Sat", value: $item.settings.saturation, range: -1...1) { onReprocess() }

            Toggle(isOn: $item.settings.watermark) {
                Text("watermark")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .toggleStyle(.checkbox)
            .onChange(of: item.settings.watermark) { _, _ in onReprocess() }
        }
    }
}

// MARK: - Helpers

struct SliderRow: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    var onCommit: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .leading)
            Slider(value: $value, in: range)
                .controlSize(.mini)
                .onChange(of: value) { _, _ in onCommit() }
            Text(String(format: "%.2f", value))
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
    }
}

struct ChipButtonStyle: ButtonStyle {
    var accent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(accent ? Color.accentColor.opacity(0.85) : Color.white.opacity(0.08))
            .foregroundStyle(accent ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
