import AppKit
import ImageIO

enum ExportManager {
    static func chooseOutputFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Export Here"
        panel.message = "Choose export destination"
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func exportImage(_ image: NSImage, originalURL: URL, to folder: URL) throws -> URL {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ExportError.renderFailed
        }

        let stem = originalURL.deletingPathExtension().lastPathComponent
        let outURL = folder.appendingPathComponent("\(stem)_ag.jpg")

        guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, "public.jpeg" as CFString, 1, nil) else {
            throw ExportError.writeFailed
        }

        CGImageDestinationAddImage(dest, cgImage, [
            kCGImageDestinationLossyCompressionQuality: 0.93,
            kCGImagePropertyOrientation: 1
        ] as CFDictionary)

        guard CGImageDestinationFinalize(dest) else { throw ExportError.writeFailed }
        return outURL
    }

    static func videoOutputURL(for original: URL, in folder: URL) -> URL {
        let stem = original.deletingPathExtension().lastPathComponent
        return folder.appendingPathComponent("\(stem)_ag.mov")
    }
}

enum ExportError: LocalizedError {
    case renderFailed, writeFailed

    var errorDescription: String? {
        switch self {
        case .renderFailed: return "Failed to render image"
        case .writeFailed:  return "Failed to write output file"
        }
    }
}
