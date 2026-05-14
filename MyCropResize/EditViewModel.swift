import SwiftUI
import Combine
import Photos

@MainActor
final class EditViewModel: ObservableObject {
    @Published var sourceImage: UIImage
    @Published var processedImage: UIImage?
    @Published var cropRect: CGRect = .zero
    @Published var imageDisplayRect: CGRect = .zero
    @Published var selectedAspectRatio: AspectRatio = .free
    @Published var selectedPreset: PresetSize? = nil
    @Published var widthText: String = ""
    @Published var heightText: String = ""
    @Published var keepAspectRatio: Bool = true
    @Published var saveFormat: SaveFormat = .jpeg
    @Published var isCropEnabled: Bool = false
    @Published var alertMessage: String = ""
    @Published var showAlert: Bool = false
    @Published var showSaveSuccess: Bool = false
    @Published var isSaving: Bool = false
    @Published var hasSaved: Bool = false

    private var hasAddedToRecent = false

    init(image: UIImage) {
        self.sourceImage = image
        let size = image.size
        widthText = "\(Int(size.width))"
        heightText = "\(Int(size.height))"
    }

    var outputWidth: Int { Int(widthText) ?? Int(sourceImage.size.width) }
    var outputHeight: Int { Int(heightText) ?? Int(sourceImage.size.height) }

    func applyPreset(_ preset: PresetSize) {
        selectedPreset = preset
        widthText = "\(preset.width)"
        heightText = "\(preset.height)"
    }

    func onWidthChanged(_ newVal: String) {
        guard keepAspectRatio, let w = Int(newVal), w > 0 else { return }
        let (refW, refH) = effectiveAspectRatioDimensions()
        guard refW > 0 else { return }
        let h = Int(CGFloat(w) * refH / refW)
        heightText = "\(h)"
    }

    func onHeightChanged(_ newVal: String) {
        guard keepAspectRatio, let h = Int(newVal), h > 0 else { return }
        let (refW, refH) = effectiveAspectRatioDimensions()
        guard refH > 0 else { return }
        let w = Int(CGFloat(h) * refW / refH)
        widthText = "\(w)"
    }

    // クロップが有効な場合はクロップ領域の、そうでなければ元画像のアスペクト比を返す
    private func effectiveAspectRatioDimensions() -> (CGFloat, CGFloat) {
        if isCropEnabled, imageDisplayRect.width > 0, imageDisplayRect.height > 0 {
            let scaleX = sourceImage.size.width / imageDisplayRect.width
            let scaleY = sourceImage.size.height / imageDisplayRect.height
            let cropW = cropRect.width * scaleX
            let cropH = cropRect.height * scaleY
            if cropW > 0, cropH > 0 { return (cropW, cropH) }
        }
        return (sourceImage.size.width, sourceImage.size.height)
    }

    // Convert display cropRect → image-space CGRect
    private func imageCropRect() -> CGRect? {
        guard isCropEnabled, imageDisplayRect.width > 0, imageDisplayRect.height > 0 else { return nil }
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
        let targetSize = CGSize(width: outputWidth, height: outputHeight)
        guard targetSize.width > 0, targetSize.height > 0 else {
            showError("Enter valid width and height.")
            return
        }
        let imgCropRect = imageCropRect()
        guard let result = ImageProcessor.cropAndResize(sourceImage, cropRect: imgCropRect, targetSize: targetSize) else {
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
        isCropEnabled = false
        selectedPreset = nil
        selectedAspectRatio = .free
        keepAspectRatio = true
        widthText = "\(Int(sourceImage.size.width))"
        heightText = "\(Int(sourceImage.size.height))"
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
