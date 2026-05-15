import SwiftUI

struct EditView: View {
    @StateObject private var vm: EditViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isFullScreenPresented = false
    @State private var imageScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var imageOffset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var previewViewSize: CGSize = .zero

    init(image: UIImage, filename: String? = nil) {
        _vm = StateObject(wrappedValue: EditViewModel(image: image, filename: filename))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                imageInfoSection
                imagePreviewSection
                presetSection
                resizeSection
                actionButtons
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .navigationTitle("Edit Screenshot")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $vm.showAlert) {
            Button("OK") {}
        } message: {
            Text(vm.alertMessage)
        }
        .overlay(saveSuccessBanner, alignment: .top)
    }

    // MARK: - Image Info

    private var imageInfoSection: some View {
        HStack(spacing: 10) {
            if let name = vm.filename {
                Text(name)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Text("\(Int(vm.sourceImage.size.width * vm.sourceImage.scale)) × \(Int(vm.sourceImage.size.height * vm.sourceImage.scale)) px")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Image Preview

    private var imagePreviewSection: some View {
        VStack(spacing: 0) {
            ZStack {
                Color(.systemGray6)
                if let processed = vm.processedImage {
                    Image(uiImage: processed)
                        .resizable()
                        .scaledToFit()
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(Color.black.opacity(0.45))
                                .clipShape(Circle())
                                .padding(8)
                        }
                        .onTapGesture { isFullScreenPresented = true }
                        .contentShape(Rectangle())
                } else {
                    GeometryReader { geo in
                        let imgSize = vm.sourceImage.size
                        let baseRect = fitRect(imageSize: imgSize, in: geo.size)
                        let effRect = effectiveDisplayRect(base: baseRect, viewSize: geo.size, scale: imageScale, offset: imageOffset)
                        let visibleImageRect = effRect.intersection(CGRect(origin: .zero, size: geo.size))
                        ZStack {
                            Color.clear
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 4)
                                        .onChanged { value in
                                            let newOff = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                            let dx = newOff.width - imageOffset.width
                                            let dy = newOff.height - imageOffset.height
                                            imageOffset = newOff
                                            vm.cropRect = vm.cropRect.offsetBy(dx: dx, dy: dy)
                                            vm.imageDisplayRect = effectiveDisplayRect(
                                                base: baseRect, viewSize: geo.size,
                                                scale: imageScale, offset: newOff
                                            )
                                        }
                                        .onEnded { _ in lastOffset = imageOffset }
                                )
                            Image(uiImage: vm.sourceImage)
                                .resizable()
                                .frame(width: effRect.width, height: effRect.height)
                                .position(x: effRect.midX, y: effRect.midY)
                                .allowsHitTesting(false)
                            CropOverlayView(
                                cropRect: Binding(
                                    get: { vm.cropRect },
                                    set: { vm.cropRect = $0; vm.onManualCropChanged() }
                                ),
                                imageRect: visibleImageRect.isNull ? effRect : visibleImageRect,
                                aspectRatio: .free
                            )
                        }
                        .onAppear {
                            previewViewSize = geo.size
                            vm.imageDisplayRect = baseRect
                            vm.initCropRect()
                        }
                        .onChange(of: geo.size) { _, newSize in
                            previewViewSize = newSize
                            let r = fitRect(imageSize: imgSize, in: newSize)
                            imageScale = 1; lastScale = 1
                            imageOffset = .zero; lastOffset = .zero
                            vm.imageDisplayRect = r
                            vm.initCropRect()
                        }
                    }
                    .frame(height: 220)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                guard previewViewSize.width > 0 else { return }
                                let newScale = max(1, lastScale * value)
                                let base = fitRect(imageSize: vm.sourceImage.size, in: previewViewSize)
                                imageScale = newScale
                                let newEff = effectiveDisplayRect(base: base, viewSize: previewViewSize, scale: newScale, offset: imageOffset)
                                vm.imageDisplayRect = newEff
                                let visibleBounds = newEff.intersection(CGRect(origin: .zero, size: previewViewSize))
                                if !visibleBounds.isNull {
                                    vm.cropRect = clampedRect(vm.cropRect, to: visibleBounds)
                                }
                            }
                            .onEnded { _ in lastScale = imageScale }
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if let processed = vm.processedImage {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.green)
                    Text("Processed")
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(Int(processed.size.width * processed.scale)) × \(Int(processed.size.height * processed.scale)) px")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.top, 6)
            }
        }
        .fullScreenCover(isPresented: $isFullScreenPresented) {
            if let processed = vm.processedImage {
                ImageFullScreenView(image: processed)
            }
        }
    }

    private func fitRect(imageSize: CGSize, in containerSize: CGSize) -> CGRect {
        let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
        let fitW = imageSize.width * scale
        let fitH = imageSize.height * scale
        let x = (containerSize.width - fitW) / 2
        let y = (containerSize.height - fitH) / 2
        return CGRect(x: x, y: y, width: fitW, height: fitH)
    }

    private func effectiveDisplayRect(base: CGRect, viewSize: CGSize, scale: CGFloat, offset: CGSize) -> CGRect {
        let c = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        let newW = base.width * scale
        let newH = base.height * scale
        let cx = c.x + (base.midX - c.x) * scale + offset.width
        let cy = c.y + (base.midY - c.y) * scale + offset.height
        return CGRect(x: cx - newW / 2, y: cy - newH / 2, width: newW, height: newH)
    }

    private func clampedRect(_ rect: CGRect, to bounds: CGRect) -> CGRect {
        let w = min(rect.width, bounds.width)
        let h = min(rect.height, bounds.height)
        let x = max(bounds.minX, min(rect.minX, bounds.maxX - w))
        let y = max(bounds.minY, min(rect.minY, bounds.maxY - h))
        return CGRect(x: x, y: y, width: w, height: h)
    }

    // MARK: - Presets

    private var presetSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("Preset Sizes")
                    .font(.subheadline).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(presetSizes) { preset in
                            Button {
                                vm.applyPreset(preset)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(alignment: .lastTextBaseline, spacing: 1) {
                                        Text(preset.name)
                                            .font(.caption.bold())
                                        Text("in")
                                            .font(.system(size: 8))
                                            .foregroundStyle(.secondary)
                                    }
                                    Text("\(preset.width)×\(preset.height)")
                                        .font(.caption2)
                                }
                            }
                            .buttonStyle(ChipButtonStyle(isSelected: vm.selectedPreset?.id == preset.id))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Resize + Format

    private var resizeSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Text("Output Size (px)")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Picker("Format", selection: $vm.saveFormat) {
                        ForEach(SaveFormat.allCases, id: \.self) { fmt in
                            Text(fmt.rawValue).tag(fmt)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }

                HStack(spacing: 12) {
                    pixelField(label: "Width", text: $vm.widthText, onCommit: { vm.onWidthChanged(vm.widthText) })
                    Text("×").foregroundStyle(.secondary)
                    pixelField(label: "Height", text: $vm.heightText, onCommit: { vm.onHeightChanged(vm.heightText) })
                }

                Toggle(isOn: $vm.keepAspectRatio) {
                    Label("Keep Aspect Ratio", systemImage: "lock.open.rotation")
                        .font(.subheadline)
                }
            }
        }
    }

    private func pixelField(label: String, text: Binding<String>, onCommit: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(label, text: text)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)
                .onChange(of: text.wrappedValue) { _, newVal in onCommit() }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                vm.process()
            } label: {
                Label("Crop & Resize", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())

            HStack(spacing: 12) {
                Button {
                    vm.save()
                } label: {
                    Label("Save to Photos", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(vm.processedImage == nil || vm.isSaving || vm.hasSaved)

                Button {
                    vm.reset()
                    imageScale = 1; lastScale = 1
                    imageOffset = .zero; lastOffset = .zero
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DestructiveButtonStyle())
            }
        }
    }

    // MARK: - Success Banner

    @ViewBuilder
    private var saveSuccessBanner: some View {
        if vm.showSaveSuccess {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text("Saved to Photos!")
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.green)
            .clipShape(Capsule())
            .shadow(radius: 8)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation { vm.showSaveSuccess = false }
                }
            }
        }
    }

    // MARK: - Section Helper

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .background(Color.accentColor.opacity(configuration.isPressed ? 0.7 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .foregroundStyle(isEnabled ? Color.accentColor : Color.secondary)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isEnabled ? Color.accentColor : Color.secondary, lineWidth: 1.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .foregroundStyle(Color.red)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red, lineWidth: 1.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct ChipButtonStyle: ButtonStyle {
    var isSelected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.bold())
            .foregroundStyle(isSelected ? .white : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? Color.accentColor : Color(.systemGray5))
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - Full Screen Image Viewer

struct ImageFullScreenView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var showsControls = true

    private var pixelSize: String {
        "\(Int(image.size.width * image.scale)) × \(Int(image.size.height * image.scale)) px"
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .gesture(
                    MagnificationGesture()
                        .onChanged { scale = max(1, lastScale * $0) }
                        .onEnded { _ in lastScale = scale }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(duration: 0.3)) {
                        scale = 1
                        lastScale = 1
                    }
                }
                .onTapGesture(count: 1) {
                    withAnimation(.easeInOut(duration: 0.2)) { showsControls.toggle() }
                }

            if showsControls {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .black.opacity(0.5))
                                .padding()
                        }
                    }
                    Spacer()
                    Text(pixelSize)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.bottom, 24)
                }
                .transition(.opacity)
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    guard scale == 1, value.translation.height > 80 else { return }
                    dismiss()
                }
        )
    }
}
