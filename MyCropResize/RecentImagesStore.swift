import SwiftUI
import Combine

struct RecentImageEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let fileName: String

    var fileURL: URL {
        RecentImagesStore.storeDirectory.appendingPathComponent(fileName)
    }

    func loadImage() -> UIImage? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }
}

final class RecentImagesStore: ObservableObject {
    static let shared = RecentImagesStore()

    static var storeDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("RecentImages")
    }

    @Published private(set) var entries: [RecentImageEntry] = []

    private let maxEntries = 20
    private let metadataKey = "recentImagesMetadata"

    private init() {
        try? FileManager.default.createDirectory(at: Self.storeDirectory, withIntermediateDirectories: true)
        load()
    }

    func remove(_ entry: RecentImageEntry) {
        entries.removeAll { $0.id == entry.id }
        try? FileManager.default.removeItem(at: entry.fileURL)
        save()
    }

    func add(_ image: UIImage) {
        let id = UUID()
        let fileName = "\(id.uuidString).jpg"
        let url = Self.storeDirectory.appendingPathComponent(fileName)
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        try? data.write(to: url)

        let entry = RecentImageEntry(id: id, date: Date(), fileName: fileName)
        entries.insert(entry, at: 0)

        while entries.count > maxEntries {
            let old = entries.removeLast()
            try? FileManager.default.removeItem(at: old.fileURL)
        }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: metadataKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: metadataKey),
              let saved = try? JSONDecoder().decode([RecentImageEntry].self, from: data)
        else { return }
        entries = saved.filter { FileManager.default.fileExists(atPath: $0.fileURL.path) }
    }
}
