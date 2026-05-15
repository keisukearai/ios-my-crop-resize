import SwiftUI
import Combine
import Photos

@MainActor
final class EditViewModel: ObservableObject {
    @Published var sourceImage: UIImage
    @Published var processedImage: UIImage?
    @Published var cropRect: CGRect = .zero
    @Published var imageDisplayRect: CGRect = .zero
    @Published var selectedPreset: PresetSize? = nil
    @Published var widthText: String = ""
    @Published var heightText: String = ""
    @Published var saveFormat: SaveFormat = .jpeg
    @Published var alertMessage: String = ""
    @Published var showAlert: Bool = false
    @Published var showSaveSuccess: Bool = false
    @Published var isSaving: Bool = false
    @Published var hasSaved: Bool = false

    var filename: String?
    private var hasAddedToRecent = false

    init(image: UIImage, filename: String? = nil) {
        self.sourceImage = image
        self.filename = filename
        let size = image.size
        let scale = image.scale
        widthText = "\(Int(size.width * scale))"
        heightText = "\(Int(size.height * scale))"
    }

    func applyPreset(_ preset: PresetSize) {
        selectedPreset = preset
        widthText = "\(preset.width)"
        heightText = "\(preset.height)"
        updateCropRectForPreset(preset)
    }

    func onManualCropChanged() {
        guard imageDisplayRect.width > 0, imageDisplayRect.height > 0 else { return }
        selectedPreset = nil
        let scaleX = sourceImage.size.width * sourceImage.scale / imageDisplayRect.width
        let scaleY = sourceImage.size.height * sourceImage.scale / imageDisplayRect.height
        let pixelW = max(1, Int((cropRect.width * scaleX).rounded()))
        let pixelH = max(1, Int((cropRect.height * scaleY).rounded()))
        widthText = "\(pixelW)"
        heightText = "\(pixelH)"
    }

    private func updateCropRectForPreset(_ preset: PresetSize) {
        guard imageDisplayRect.width > 0, imageDisplayRect.height > 0 else { return }
        let ar = CGFloat(preset.width) / CGFloat(preset.height)
        let maxW = imageDisplayRect.width
        let maxH = imageDisplayRect.height
        let newW: CGFloat
        let newH: CGFloat
        if maxW / maxH > ar {
            newH = maxH
            newW = newH * ar
        } else {
            newW = maxW
            newH = newW / ar
        }
        cropRect = CGRect(
            x: imageDisplayRect.midX - newW / 2,
            y: imageDisplayRect.midY - newH / 2,
            width: newW,
            height: newH
        )
    }

    private func imageCropRect() -> CGRect? {
        guard imageDisplayRect.width > 0, imageDisplayRect.height > 0 else { return nil }
        let scaleX = sourceImage.size.width / imageDisplayRect.width
        let scaleY = sourceImage.size.height / imageDisplayRect.height
        let rel = CGRect(
            x: cropRect.minX - imageDisplayRect.minX,
            y: cropRect.minY - imageDisplayRect.minY,
            width: cropRect.width,
            height: cropRect.height
        )
        return CGRect(
            x: rel.minX * scaleX,
            y: rel.minY * scaleY,
            width: rel.width * scaleX,
            height: rel.height * scaleY
        )
    }

    func process() {
        let imgCropRect = imageCropRect()
        let result: UIImage?
        if let preset = selectedPreset {
            let targetSize = CGSize(width: preset.width, height: preset.height)
            result = ImageProcessor.cropAndResize(sourceImage, cropRect: imgCropRect, targetSize: targetSize)
        } else if let rect = imgCropRect {
            result = ImageProcessor.crop(sourceImage, to: rect)
        } else {
            result = sourceImage
        }
        guard let result else {
            showError("Image processing failed.")
            return
        }
        processedImage = result
        if !hasAddedToRecent {
            RecentImagesStore.shared.add(result)
            hasAddedToRecent = true
        }
    }

    func save() {
        guard !isSaving, !hasSaved else { return }
        guard let img = processedImage ?? { process(); return processedImage }() else {
            showError("Process the image first.")
            return
        }
        let data: Data?
        switch saveFormat {
        case .png:  data = ImageProcessor.pngData(from: img)
        case .jpeg: data = ImageProcessor.jpegData(from: img)
        }
        guard let imageData = data else {
            showError("Failed to encode image.")
            return
        }
        isSaving = true
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                guard status == .authorized || status == .limited else {
                    self.isSaving = false
                    self.showError("Photo library access denied. Enable it in Settings.")
                    return
                }
                PHPhotoLibrary.shared().performChanges({
                    let request = PHAssetCreationRequest.forAsset()
                    request.addResource(with: .photo, data: imageData, options: nil)
                }) { success, error in
                    DispatchQueue.main.async {
                        self.isSaving = false
                        if success {
                            self.hasSaved = true
                            self.showSaveSuccess = true
                        } else {
                            self.showError(error?.localizedDescription ?? "Save failed.")
                        }
                    }
                }
            }
        }
    }

    func reset() {
        processedImage = nil
        selectedPreset = nil
        widthText = "\(Int(sourceImage.size.width * sourceImage.scale))"
        heightText = "\(Int(sourceImage.size.height * sourceImage.scale))"
        hasSaved = false
        initCropRect()
    }

    func initCropRect() {
        if imageDisplayRect != .zero {
            cropRect = imageDisplayRect
        }
    }

    private func showError(_ msg: String) {
        alertMessage = msg
        showAlert = true
    }
}
