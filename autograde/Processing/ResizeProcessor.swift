import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - App Store sizes

enum AppStoreSize: String, CaseIterable, Identifiable {
    case iphone65Portrait   = "6.5\"  1242 × 2688"
    case iphone65Landscape  = "6.5\"  2688 × 1242"
    case iphone67Portrait   = "6.7\"  1284 × 2778"
    case iphone67Landscape  = "6.7\"  2778 × 1284"

    var id: String { rawValue }

    var dimensions: CGSize {
        switch self {
        case .iphone65Portrait:  return CGSize(width: 1242, height: 2688)
        case .iphone65Landscape: return CGSize(width: 2688, height: 1242)
        case .iphone67Portrait:  return CGSize(width: 1284, height: 2778)
        case .iphone67Landscape: return CGSize(width: 2778, height: 1284)
        }
    }

    var isPortrait: Bool { dimensions.height > dimensions.width }

    /// Pick the best match for a given image size.
    static func nearest(for size: CGSize) -> AppStoreSize {
        let portrait = size.height >= size.width
        let pool = allCases.filter { $0.isPortrait == portrait }
        let src = size.width * size.height
        return pool.min(by: {
            let a = $0.dimensions.width * $0.dimensions.height
            let b = $1.dimensions.width * $1.dimensions.height
            return abs(a - src) < abs(b - src)
        }) ?? (portrait ? .iphone67Portrait : .iphone67Landscape)
    }
}

// MARK: - Processor

actor ResizeProcessor {
    static let shared = ResizeProcessor()
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    /// Scale-to-fill + center-crop to exact App Store dimensions. High quality Lanczos.
    func resize(image: NSImage, to target: AppStoreSize) -> NSImage? {
        guard let cgSrc = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        let srcW = CGFloat(cgSrc.width)
        let srcH = CGFloat(cgSrc.height)
        let tW   = target.dimensions.width
        let tH   = target.dimensions.height

        // Scale so image fills target (scale-to-fill)
        let scale = max(tW / srcW, tH / srcH)
        let scaledW = srcW * scale
        let scaledH = srcH * scale

        // Lanczos scale
        var ci = CIImage(cgImage: cgSrc)
        let scaleFilter = CIFilter.lanczosScaleTransform()
        scaleFilter.inputImage = ci
        scaleFilter.scale = Float(scale)
        scaleFilter.aspectRatio = 1.0
        ci = scaleFilter.outputImage ?? ci

        // Center crop to exact target
        let cropX = (scaledW - tW) / 2
        let cropY = (scaledH - tH) / 2
        let cropRect = CGRect(x: cropX, y: cropY, width: tW, height: tH)
        ci = ci.cropped(to: cropRect)
            .transformed(by: CGAffineTransform(translationX: -cropX, y: -cropY))

        guard let cgOut = ciContext.createCGImage(ci, from: CGRect(origin: .zero, size: target.dimensions)) else { return nil }
        return NSImage(cgImage: cgOut, size: target.dimensions)
    }

    func exportResized(_ image: NSImage, originalURL: URL, size: AppStoreSize, to folder: URL) throws -> URL {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { throw ExportError.renderFailed }

        let stem  = originalURL.deletingPathExtension().lastPathComponent
        let label = size.rawValue
            .replacingOccurrences(of: "\"", with: "in")
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "×", with: "x")
        let outURL = folder.appendingPathComponent("\(stem)_\(label).png")

        guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, "public.png" as CFString, 1, nil) else { throw ExportError.writeFailed }
        CGImageDestinationAddImage(dest, cg, nil)
        guard CGImageDestinationFinalize(dest) else { throw ExportError.writeFailed }
        return outURL
    }
}
