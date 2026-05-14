import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
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
                    EditView(image: img)
                }
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            isLoading = true
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    selectedImage = uiImage
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
                featureChip(icon: "square.and.arrow.down", label: "Save PNG/JPEG")
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
            Text("最近編集した画像")
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
            let size = geo.size.width
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.24)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0, green: 0.4, blue: 0.8),
                                     Color(red: 0.04, green: 0.24, blue: 0.59)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )

                ResizeFrameShape(size: size)
                    .stroke(Color.white, lineWidth: size * 0.045)
                    .padding(size * 0.22)

                ResizeArrowsShape(size: size)
                    .fill(Color.white)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

struct ResizeFrameShape: Shape {
    let size: CGFloat
    func path(in rect: CGRect) -> Path {
        let pad = size * 0.22
        let inner = rect.insetBy(dx: pad, dy: pad + size * 0.04)
        var p = Path()
        p.addRoundedRect(in: inner, cornerSize: CGSize(width: size * 0.06, height: size * 0.06))
        return p
    }
}

struct ResizeArrowsShape: Shape {
    let size: CGFloat
    func path(in rect: CGRect) -> Path {
        let pad = size * 0.22
        let inner = rect.insetBy(dx: pad, dy: pad + size * 0.04)
        let arm: CGFloat = size * 0.14
        let tip: CGFloat = size * 0.05
        let lw:  CGFloat = size * 0.045

        let corners: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (inner.minX, inner.minY, -1, -1),
            (inner.maxX, inner.minY,  1, -1),
            (inner.minX, inner.maxY, -1,  1),
            (inner.maxX, inner.maxY,  1,  1),
        ]

        var p = Path()
        for (cx, cy, dx, dy) in corners {
            let ox = cx + dx * (size * 0.035)
            let oy = cy + dy * (size * 0.035)
            // horizontal arm
            let hx = ox + dx * arm
            p.addRect(CGRect(
                x: min(ox, hx), y: oy - lw/2,
                width: arm, height: lw
            ))
            // h arrowhead
            p.move(to: CGPoint(x: hx, y: oy))
            p.addLine(to: CGPoint(x: hx - dx*tip, y: oy - tip*0.6))
            p.addLine(to: CGPoint(x: hx - dx*tip, y: oy + tip*0.6))
            p.closeSubpath()
            // vertical arm
            let vy = oy + dy * arm
            p.addRect(CGRect(
                x: ox - lw/2, y: min(oy, vy),
                width: lw, height: arm
            ))
            // v arrowhead
            p.move(to: CGPoint(x: ox, y: vy))
            p.addLine(to: CGPoint(x: ox - tip*0.6, y: vy - dy*tip))
            p.addLine(to: CGPoint(x: ox + tip*0.6, y: vy - dy*tip))
            p.closeSubpath()
        }
        return p
    }
}

#Preview {
    ContentView()
}
