import UIKit

// MARK: - Image Cache (memory + disk)

final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()

    private let memory = NSCache<NSString, UIImage>()
    private let diskURL: URL
    private let ioQueue = DispatchQueue(label: "vk.image-cache.io", qos: .utility)

    private init() {
        memory.countLimit        = 500
        memory.totalCostLimit    = 150 * 1024 * 1024 // 150 MB
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskURL = caches.appendingPathComponent("VKImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskURL, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    func get(url: URL) -> UIImage? {
        let key = cacheKey(url)
        if let img = memory.object(forKey: key as NSString) { return img }
        let path = diskPath(key)
        guard let data = try? Data(contentsOf: path),
              let img = UIImage(data: data) else { return nil }
        memory.setObject(img, forKey: key as NSString, cost: data.count)
        return img
    }

    func set(_ image: UIImage, for url: URL) {
        let key = cacheKey(url)
        let data = image.jpegData(compressionQuality: 0.92) ?? Data()
        memory.setObject(image, forKey: key as NSString, cost: data.count)
        let path = diskPath(key)
        ioQueue.async { try? data.write(to: path, options: .atomic) }
    }

    /// Async load: memory → disk → network
    func load(url: URL) async -> UIImage? {
        if let cached = get(url: url) { return cached }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let img = UIImage(data: data) else { return nil }
        set(img, for: url)
        return img
    }

    // MARK: - Helpers

    private func cacheKey(_ url: URL) -> String {
        "\(abs(url.absoluteString.hashValue))"
    }

    private func diskPath(_ key: String) -> URL {
        diskURL.appendingPathComponent(key)
    }
}
