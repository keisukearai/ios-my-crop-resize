import Foundation
import CoreGraphics

struct PresetSize: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let width: Int
    let height: Int

    var displayName: String { "\(name) (\(width)×\(height))" }
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
