import SwiftUI

struct EditView: View {
    @StateObject private var vm: EditViewModel
    @Environment(\.dismiss) private var dismiss

    init(image: UIImage) {
        _vm = StateObject(wrappedValue: EditViewModel(image: image))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                imagePreviewSection
                cropToggleSection
                if vm.isCropEnabled { aspectRatioSection }
                presetSection
                resizeSection
                formatSection
                actionButtons
            }
            .padding()
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

    // MARK: - Image Preview

    private var imagePreviewSection: some View {
        ZStack {
            Color(.systemGray6)
            if let processed = vm.processedImage {
                Image(uiImage: processed)
                    .resizable()
                    .scaledToFit()
                    .overlay(alignment: .topTrailing) {
                        Label("Processed", systemImage: "checkmark.seal.fill")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(Color.green.opacity(0.85))
                            .clipShape(Capsule())
                            .padding(8)
                    }
            } else {
                GeometryReader { geo in
                    let imgSize = vm.sourceImage.size
                    let displayRect = fitRect(imageSize: imgSize, in: geo.size)
                    Image(uiImage: vm.sourceImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .overlay {
                            if vm.isCropEnabled {
                                CropOverlayView(
                                    cropRect: $vm.cropRect,
                                    imageRect: displayRect,
                                    aspectRatio: vm.selectedAspectRatio
                                )
                            }
                        }
                        .onAppear {
                            vm.imageDisplayRect = displayRect
                            vm.initCropRect()
                        }
                        .onChange(of: geo.size) { _, newSize in
                            let r = fitRect(imageSize: imgSize, in: newSize)
                            vm.imageDisplayRect = r
                        }
                }
                .frame(height: 300)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: vm.processedImage != nil ? nil : 300)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func fitRect(imageSize: CGSize, in containerSize: CGSize) -> CGRect {
        let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
        let fitW = imageSize.width * scale
        let fitH = imageSize.height * scale
        let x = (containerSize.width - fitW) / 2
        let y = (containerSize.height - fitH) / 2
        return CGRect(x: x, y: y, width: fitW, height: fitH)
    }

    // MARK: - Crop

    private var cropToggleSection: some View {
        sectionCard {
            Toggle(isOn: $vm.isCropEnabled) {
                Label("Enable Crop", systemImage: "crop")
                    .fontWeight(.medium)
            }
            .onChange(of: vm.isCropEnabled) { _, enabled in
                if enabled { vm.initCropRect() }
            }
        }
    }

    private var aspectRatioSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Aspect Ratio")
                    .font(.subheadline).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(AspectRatio.allCases, id: \.self) { ratio in
                            Button(ratio.rawValue) {
                                vm.selectedAspectRatio = ratio
                            }
                            .buttonStyle(ChipButtonStyle(isSelected: vm.selectedAspectRatio == ratio))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Presets

    private var presetSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Preset Sizes")
                    .font(.subheadline).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(presetSizes) { preset in
                            Button {
                                vm.applyPreset(preset)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.name)
                                        .font(.caption.bold())
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

    // MARK: - Resize

    private var resizeSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Output Size (px)")
                    .font(.subheadline).foregroundStyle(.secondary)

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

    // MARK: - Format

    private var formatSection: some View {
        sectionCard {
            HStack {
                Label("Save Format", systemImage: "square.and.arrow.down")
                    .font(.subheadline).fontWeight(.medium)
                Spacer()
                Picker("Format", selection: $vm.saveFormat) {
                    ForEach(SaveFormat.allCases, id: \.self) { fmt in
                        Text(fmt.rawValue).tag(fmt)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 130)
            }
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
            .padding()
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
