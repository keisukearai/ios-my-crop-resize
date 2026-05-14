import UIKit
import CoreGraphics

struct ImageProcessor {

    static func crop(_ image: UIImage, to rect: CGRect) -> UIImage? {
        let scale = image.scale
        let scaledRect = CGRect(
            x: rect.origin.x * scale,
            y: rect.origin.y * scale,
            width: rect.size.width * scale,
            height: rect.size.height * scale
        )
        guard let cgImage = image.cgImage?.cropping(to: scaledRect) else { return nil }
        return UIImage(cgImage: cgImage, scale: scale, orientation: image.imageOrientation)
    }

    static func resize(_ image: UIImage, to size: CGSize) -> UIImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    static func cropAndResize(_ image: UIImage, cropRect: CGRect?, targetSize: CGSize) -> UIImage? {
        var working = image
        if let rect = cropRect {
            guard let cropped = crop(working, to: rect) else { return nil }
            working = cropped
        }
        return resize(working, to: targetSize)
    }

    static func pngData(from image: UIImage) -> Data? {
        image.pngData()
    }

    static func jpegData(from image: UIImage, quality: CGFloat = 0.95) -> Data? {
        image.jpegData(compressionQuality: quality)
    }
}
