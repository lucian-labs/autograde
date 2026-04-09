import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins

actor VideoProcessor {
    static let shared = VideoProcessor()
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    func process(url: URL, settings: EditSettings, outputURL: URL) async throws {
        let asset = AVURLAsset(url: url)
        let comp = AVMutableComposition()

        guard
            let srcVideoTrack = try await asset.loadTracks(withMediaType: .video).first,
            let srcAudioTrack = try? await asset.loadTracks(withMediaType: .audio).first,
            let compVideoTrack = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
            let compAudioTrack = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { throw VideoExportError.trackLoadFailed }

        let duration = try await asset.load(.duration)
        let range = CMTimeRange(start: .zero, duration: duration)

        try compVideoTrack.insertTimeRange(range, of: srcVideoTrack, at: .zero)
        try compAudioTrack.insertTimeRange(range, of: srcAudioTrack, at: .zero)

        let videoComp = AVMutableVideoComposition(asset: comp) { [settings] request in
            var ci = request.sourceImage.clampedToExtent()

            if settings.exposure != 0 {
                let f = CIFilter.exposureAdjust()
                f.inputImage = ci; f.ev = settings.exposure
                ci = f.outputImage?.cropped(to: request.sourceImage.extent) ?? ci
            }
            if settings.contrast != 0 || settings.saturation != 0 {
                let f = CIFilter.colorControls()
                f.inputImage = ci
                f.contrast = 1.0 + settings.contrast
                f.saturation = 1.0 + settings.saturation
                ci = f.outputImage?.cropped(to: request.sourceImage.extent) ?? ci
            }
            if settings.grain > 0, let grain = Self.grainFilter(for: request.sourceImage.extent, intensity: settings.grain) {
                if let blend = CIFilter(name: "CISoftLightBlendMode") {
                    blend.setValue(grain, forKey: kCIInputImageKey)
                    blend.setValue(ci, forKey: kCIInputBackgroundImageKey)
                    ci = blend.outputImage?.cropped(to: request.sourceImage.extent) ?? ci
                }
            }

            request.finish(with: ci, context: nil)
        }

        let naturalSize = try await srcVideoTrack.load(.naturalSize)
        videoComp.renderSize = naturalSize

        guard let session = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality) else {
            throw VideoExportError.sessionFailed
        }
        session.videoComposition = videoComp
        session.outputURL = outputURL
        session.outputFileType = .mov

        await session.export()
        if let error = session.error { throw error }
    }

    private static func grainFilter(for extent: CGRect, intensity: Float) -> CIImage? {
        guard
            let noiseFilter = CIFilter(name: "CIRandomGenerator"),
            let raw = noiseFilter.outputImage
        else { return nil }

        let cropped = raw.cropped(to: extent)
        let matrix = CIFilter.colorMatrix()
        matrix.inputImage = cropped
        let v = CGFloat(intensity * 0.12)
        matrix.rVector = CIVector(x: v, y: v, z: v, w: 0)
        matrix.gVector = CIVector(x: v, y: v, z: v, w: 0)
        matrix.bVector = CIVector(x: v, y: v, z: v, w: 0)
        matrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        matrix.biasVector = CIVector(x: -v * 0.5, y: -v * 0.5, z: -v * 0.5, w: 0)
        return matrix.outputImage
    }
}

enum VideoExportError: Error {
    case trackLoadFailed, sessionFailed
}
