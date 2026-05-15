import UIKit
import CoreGraphics

struct ImageProcessor {

    static func crop(_ image: UIImage, to rect: CGRect) -> UIImage? {
        // rect is in UIImage logical point coordinates (orientation-aware).
        // Use UIGraphicsImageRenderer so orientation is applied correctly,
        // unlike cgImage.cropping(to:) which operates on raw pixel space.
        let scale = image.scale
        let outputSize = CGSize(width: rect.width * scale, height: rect.height * scale)
        guard outputSize.width > 0, outputSize.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(
                x: -rect.origin.x * scale,
                y: -rect.origin.y * scale,
                width: image.size.width * scale,
                height: image.size.height * scale
            ))
        }
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
