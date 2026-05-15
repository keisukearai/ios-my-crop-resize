import Foundation
import CoreGraphics

struct PresetSize: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let width: Int
    let height: Int

    var displayName: String { "\(name) (\(width)×\(height))" }
}

enum AspectRatio: String, CaseIterable {
    case free = "Free"
    case ratio1x1 = "1:1"
    case ratio4x3 = "4:3"
    case ratio16x9 = "16:9"
    case ratio9x16 = "9:16"
    case appStore = "App Store"

    var value: CGFloat? {
        switch self {
        case .free: return nil
        case .ratio1x1: return 1.0
        case .ratio4x3: return 4.0 / 3.0
        case .ratio16x9: return 16.0 / 9.0
        case .ratio9x16: return 9.0 / 16.0
        case .appStore: return 9.0 / 19.5
        }
    }
}

let presetSizes: [PresetSize] = [
    PresetSize(name: "iPhone 6.7", width: 1290, height: 2796),
    PresetSize(name: "iPhone 6.5", width: 1242, height: 2688),
    PresetSize(name: "iPhone 5.5", width: 1242, height: 2208),
    PresetSize(name: "iPad 13",    width: 2064, height: 2752),
    PresetSize(name: "iPad 12.9",  width: 2048, height: 2732),
]

enum SaveFormat: String, CaseIterable {
    case jpeg = "JPEG"
    case png = "PNG"
}
