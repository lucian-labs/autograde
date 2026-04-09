import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

actor ImageProcessor {
    static let shared = ImageProcessor()
    private let context = CIContext(options: [.useSoftwareRenderer: false])

    func process(image: NSImage, settings: EditSettings) -> NSImage? {
        guard let cgSrc = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        var ci = CIImage(cgImage: cgSrc)

        // Exposure
        if settings.exposure != 0 {
            let f = CIFilter.exposureAdjust()
            f.inputImage = ci
            f.ev = settings.exposure
            ci = f.outputImage ?? ci
        }

        // Contrast + saturation
        if settings.contrast != 0 || settings.saturation != 0 {
            let f = CIFilter.colorControls()
            f.inputImage = ci
            f.contrast = 1.0 + settings.contrast
            f.saturation = 1.0 + settings.saturation
            f.brightness = 0
            ci = f.outputImage ?? ci
        }

        // Film grain
        if settings.grain > 0 {
            ci = applyGrain(to: ci, intensity: settings.grain)
        }

        guard let cgOut = context.createCGImage(ci, from: ci.extent) else { return nil }
        let result = NSImage(cgImage: cgOut, size: image.size)

        // Watermark
        guard settings.watermark else { return result }
        return applyWatermark(to: result, settings: settings)
    }

    private func applyGrain(to image: CIImage, intensity: Float) -> CIImage {
        guard
            let noiseFilter = CIFilter(name: "CIRandomGenerator"),
            let rawNoise = noiseFilter.outputImage
        else { return image }

        let cropRect = image.extent
        let cropped = rawNoise.cropped(to: cropRect)

        // Grayscale + scale intensity
        let matrix = CIFilter.colorMatrix()
        matrix.inputImage = cropped
        let v = CGFloat(intensity * 0.12)
        matrix.rVector = CIVector(x: v, y: v, z: v, w: 0)
        matrix.gVector = CIVector(x: v, y: v, z: v, w: 0)
        matrix.bVector = CIVector(x: v, y: v, z: v, w: 0)
        matrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        matrix.biasVector = CIVector(x: -v * 0.5, y: -v * 0.5, z: -v * 0.5, w: 0)

        guard let grain = matrix.outputImage else { return image }

        // Soft light blend for organic look
        guard let blend = CIFilter(name: "CISoftLightBlendMode") else { return image }
        blend.setValue(grain, forKey: kCIInputImageKey)
        blend.setValue(image, forKey: kCIInputBackgroundImageKey)
        return blend.outputImage ?? image
    }

    private func applyWatermark(to image: NSImage, settings: EditSettings) -> NSImage {
        let result = NSImage(size: image.size)
        result.lockFocus()
        defer { result.unlockFocus() }

        image.draw(in: NSRect(origin: .zero, size: image.size))

        let fontSize = max(image.size.width * 0.028, 14)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(CGFloat(settings.watermarkOpacity)),
        ]
        let str = NSAttributedString(string: settings.watermarkText, attributes: attrs)
        let sz = str.size()
        let pad = image.size.width * 0.022

        let pt: NSPoint
        switch settings.watermarkPosition {
        case .bottomRight: pt = NSPoint(x: image.size.width  - sz.width - pad, y: pad)
        case .bottomLeft:  pt = NSPoint(x: pad, y: pad)
        case .topRight:    pt = NSPoint(x: image.size.width  - sz.width - pad, y: image.size.height - sz.height - pad)
        case .topLeft:     pt = NSPoint(x: pad, y: image.size.height - sz.height - pad)
        }

        str.draw(at: pt)
        return result
    }
}
