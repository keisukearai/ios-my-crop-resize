import SwiftUI
import PhotosUI
import Photos

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var selectedImageFilename: String? = nil
    @State private var showEdit = false
    @State private var isLoading = false
    @ObservedObject private var recentStore = RecentImagesStore.shared

    var body: some View {
        NavigationStack {
            ZStack {
                background
                ScrollView {
                    VStack(spacing: 0) {
                        heroSection
                            .padding(.top, 40)
                        if !recentStore.entries.isEmpty {
                            recentSection
                                .padding(.top, 28)
                        }
                        selectButton
                            .padding(.top, 32)
                            .padding(.bottom, 60)
                    }
                }
            }
            .navigationDestination(isPresented: $showEdit) {
                if let img = selectedImage {
                    EditView(image: img, filename: selectedImageFilename)
                }
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            isLoading = true
            Task {
                var filename: String? = nil
                if let identifier = newItem.itemIdentifier {
                    let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                    if status == .authorized || status == .limited {
                        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
                        if let asset = assets.firstObject {
                            filename = PHAssetResource.assetResources(for: asset).first?.originalFilename
                        }
                    }
                }
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    selectedImage = uiImage
                    selectedImageFilename = filename
                    showEdit = true
                }
                isLoading = false
            }
        }
    }

    // MARK: - Background

    private var background: some View {
        LinearGradient(
            colors: [Color(.systemBackground), Color.accentColor.opacity(0.08)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 24) {
            AppLogoView()
                .frame(width: 100, height: 100)

            VStack(spacing: 8) {
                Text("MyCropResize")
                    .font(.largeTitle.bold())

                Text("Resize screenshots for\niOS app development")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            featuresGrid
        }
        .padding(.horizontal, 32)
    }

    private var featuresGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                featureChip(icon: "arrow.up.left.and.arrow.down.right", label: "Crop")
                featureChip(icon: "aspectratio", label: "Resize")
            }
            HStack(spacing: 10) {
                featureChip(icon: "square.grid.2x2", label: "Presets")
                featureChip(icon: "square.and.arrow.down", label: "Save JPEG/PNG")
            }
        }
        .padding(.top, 8)
    }

    private func featureChip(icon: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundStyle(Color.accentColor)
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Recent Images

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recently Edited Images")
                .font(.headline)
                .padding(.horizontal, 32)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recentStore.entries) { entry in
                        Button {
                            openRecent(entry)
                        } label: {
                            RecentThumbnailView(entry: entry) {
                                recentStore.remove(entry)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 32)
            }
        }
    }

    private func openRecent(_ entry: RecentImageEntry) {
        isLoading = true
        Task.detached(priority: .userInitiated) {
            let image = entry.loadImage()
            await MainActor.run {
                isLoading = false
                if let image {
                    selectedImage = image
                    showEdit = true
                }
            }
        }
    }

    // MARK: - Select Button

    private var selectButton: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Select Screenshot", systemImage: "photo.on.rectangle.angled")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
            }
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .background(Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.accentColor.opacity(0.35), radius: 8, y: 4)
        }
        .simultaneousGesture(TapGesture().onEnded { selectedItem = nil })
        .padding(.horizontal, 32)
        .disabled(isLoading)
    }
}

// MARK: - Recent Thumbnail

struct RecentThumbnailView: View {
    let entry: RecentImageEntry
    let onDelete: () -> Void
    @State private var image: UIImage?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d HH:mm"
        return f
    }()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray5))
                .frame(width: 80, height: 80)

            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                ProgressView()
                    .frame(width: 80, height: 80)
            }
        }
        .overlay(alignment: .bottom) {
            Text(Self.dateFormatter.string(from: entry.date))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.5))
                .clipShape(
                    .rect(bottomLeadingRadius: 10, bottomTrailingRadius: 10)
                )
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white, Color.black.opacity(0.6))
            }
            .padding(3)
        }
        .task {
            let loaded = await Task.detached(priority: .userInitiated) {
                entry.loadImage()
            }.value
            image = loaded
        }
    }
}

// MARK: - App Logo (matches AppIcon design)

struct AppLogoView: View {
    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width
            ZStack {
                // Radial gradient background
                RadialGradient(
                    colors: [Color(red: 0.24, green: 0.48, blue: 0.83),
                             Color(red: 0.07, green: 0.20, blue: 0.55)],
                    center: .center,
                    startRadius: 0,
                    endRadius: s * 0.72
                )
                // Semi-transparent rounded square overlay
                RoundedRectangle(cornerRadius: s * 0.15)
                    .fill(Color.white.opacity(0.14))
                    .padding(s * 0.098)
                // Corner crop arrows (pointing inward)
                IconCropCornersShape(s: s)
                    .fill(Color.white)
                // Inner frame, midpoint guides, crosshair
                IconFrameLinesShape(s: s)
                    .stroke(Color.white, lineWidth: s * 0.013)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

struct IconCropCornersShape: Shape {
    let s: CGFloat
    func path(in rect: CGRect) -> Path {
        let pad = s * 0.098
        let arm = s * 0.085
        let lw  = s * 0.013
        let tip = s * 0.026
        // (cornerX, cornerY, hDir: +1=right/-1=left, vDir: +1=down/-1=up)
        let corners: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (pad,   pad,   1,  1),
            (s-pad, pad,  -1,  1),
            (pad,   s-pad, 1, -1),
            (s-pad, s-pad,-1, -1),
        ]
        var p = Path()
        for (cx, cy, hd, vd) in corners {
            let hEnd = cx + hd * arm
            let vEnd = cy + vd * arm
            // Horizontal arm
            p.addRect(CGRect(x: min(cx, hEnd), y: cy - lw/2, width: arm, height: lw))
            // Horizontal arrowhead
            p.move(to: CGPoint(x: hEnd, y: cy))
            p.addLine(to: CGPoint(x: hEnd - hd*tip, y: cy - tip*0.6))
            p.addLine(to: CGPoint(x: hEnd - hd*tip, y: cy + tip*0.6))
            p.closeSubpath()
            // Vertical arm
            p.addRect(CGRect(x: cx - lw/2, y: min(cy, vEnd), width: lw, height: arm))
            // Vertical arrowhead
            p.move(to: CGPoint(x: cx, y: vEnd))
            p.addLine(to: CGPoint(x: cx - tip*0.6, y: vEnd - vd*tip))
            p.addLine(to: CGPoint(x: cx + tip*0.6, y: vEnd - vd*tip))
            p.closeSubpath()
        }
        return p
    }
}

struct IconFrameLinesShape: Shape {
    let s: CGFloat
    func path(in rect: CGRect) -> Path {
        let inner = CGRect(x: s*0.193, y: s*0.254, width: s*0.614, height: s*0.492)
        let cr    = CGSize(width: s*0.057, height: s*0.057)
        let ext   = s * 0.025
        let ca    = s * 0.033
        let mx    = inner.midX
        let my    = inner.midY
        var p = Path()
        // Inner rounded rectangle
        p.addRoundedRect(in: inner, cornerSize: cr)
        // Midpoint guide markers
        p.move(to: CGPoint(x: mx, y: inner.minY - ext))
        p.addLine(to: CGPoint(x: mx, y: inner.minY + ext))
        p.move(to: CGPoint(x: mx, y: inner.maxY - ext))
        p.addLine(to: CGPoint(x: mx, y: inner.maxY + ext))
        p.move(to: CGPoint(x: inner.minX - ext, y: my))
        p.addLine(to: CGPoint(x: inner.minX + ext, y: my))
        p.move(to: CGPoint(x: inner.maxX - ext, y: my))
        p.addLine(to: CGPoint(x: inner.maxX + ext, y: my))
        // Center crosshair
        p.move(to: CGPoint(x: mx - ca, y: my))
        p.addLine(to: CGPoint(x: mx + ca, y: my))
        p.move(to: CGPoint(x: mx, y: my - ca))
        p.addLine(to: CGPoint(x: mx, y: my + ca))
        return p
    }
}

#Preview {
    ContentView()
}
