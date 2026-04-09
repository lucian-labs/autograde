import SwiftUI

struct CarouselView: View {
    let items: [MediaItem]
    @Binding var selectedID: UUID?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(items) { item in
                        CarouselThumb(item: item, isSelected: selectedID == item.id)
                            .id(item.id)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedID = item.id
                                    proxy.scrollTo(item.id, anchor: .center)
                                }
                            }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: selectedID) { _, id in
                guard let id else { return }
                withAnimation { proxy.scrollTo(id, anchor: .center) }
            }
        }
        .frame(height: 96)
        .background(.ultraThinMaterial)
    }
}

private struct CarouselThumb: View {
    @ObservedObject var item: MediaItem
    let isSelected: Bool
    @State private var hovering = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let img = item.processedImage ?? item.thumbnail {
                    Image(nsImage: img)
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

            // Video badge
            if item.type == .video {
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
                    isSelected ? Color.accentColor : Color.white.opacity(hovering ? 0.2 : 0.06),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .scaleEffect(isSelected ? 1.06 : (hovering ? 1.02 : 1.0))
        .animation(.spring(duration: 0.18), value: isSelected)
        .onHover { hovering = $0 }
    }

    // Vary width by aspect ratio if thumbnail is available, else fixed
    private var thumbWidth: CGFloat {
        guard let img = item.thumbnail else { return 72 }
        let aspect = img.size.width / img.size.height
        return min(max(aspect * 72, 48), 140)
    }
}
