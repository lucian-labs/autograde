import Foundation

struct EditSettings: Equatable {
    var exposure: Float = 0.3
    var contrast: Float = 0.05
    var saturation: Float = -0.08
    var grain: Float = 0.18
    var watermark: Bool = false
    var watermarkText: String = "EL"
    var watermarkPosition: WatermarkPosition = .bottomRight
    var watermarkOpacity: Float = 0.65

    static let autoMode = EditSettings()
    static let neutral = EditSettings(
        exposure: 0, contrast: 0, saturation: 0,
        grain: 0, watermark: false,
        watermarkText: "EL", watermarkPosition: .bottomRight, watermarkOpacity: 0.65
    )
}

enum WatermarkPosition: String, CaseIterable, Identifiable {
    case bottomRight = "Bottom Right"
    case bottomLeft  = "Bottom Left"
    case topRight    = "Top Right"
    case topLeft     = "Top Left"

    var id: String { rawValue }
}
