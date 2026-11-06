import Foundation
import UIKit

/// Illustrations, example sentences and tips from Word Atlas (词光).
/// Content: Word Atlas contributors, CC BY 4.0 — https://github.com/designfuchen/word-atlas
/// Regenerate with scripts/import_word_atlas.py.
struct AtlasEntry: Equatable {
    struct Example: Equatable {
        let en: String
        let zh: String
    }

    let imageID: String?
    let examples: [Example]
    let tip: String?
}

enum WordAtlas {
    private struct Raw: Decodable {
        let i: String?
        let e: [[String]]?
        let t: String?
    }

    private static let entries: [String: AtlasEntry] = {
        guard let url = Bundle.main.url(forResource: "atlas", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: Raw].self, from: data) else {
            return [:]
        }
        return raw.mapValues { r in
            AtlasEntry(
                imageID: r.i,
                examples: (r.e ?? []).compactMap { $0.count == 2 ? .init(en: $0[0], zh: $0[1]) : nil },
                tip: r.t
            )
        }
    }()

    static func entry(for word: String) -> AtlasEntry? {
        entries[key(word)]
    }

    static func key(_ word: String) -> String {
        word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func hasImage(_ word: String) -> Bool {
        entry(for: word)?.imageID != nil
    }

    // MARK: - Images

    private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 120
        return c
    }()

    static func imageURL(id: String) -> URL? {
        Bundle.main.url(forResource: id, withExtension: "webp", subdirectory: "Illustrations")
    }

    /// Decodes off the main thread; `maxPixel` downsamples for thumbnails so lists stay light.
    static func image(for word: String, maxPixel: CGFloat? = nil) async -> UIImage? {
        guard let id = entry(for: word)?.imageID else { return nil }
        let cacheKey = "\(id)@\(Int(maxPixel ?? 0))" as NSString
        if let cached = cache.object(forKey: cacheKey) { return cached }
        guard let url = imageURL(id: id) else { return nil }

        let image: UIImage? = await Task.detached(priority: .userInitiated) {
            guard let full = UIImage(contentsOfFile: url.path) else { return nil }
            if let maxPixel, maxPixel < full.size.width * full.scale {
                return await full.byPreparingThumbnail(ofSize: CGSize(width: maxPixel, height: maxPixel)) ?? full
            }
            return await full.byPreparingForDisplay() ?? full
        }.value
        if let image { cache.setObject(image, forKey: cacheKey) }
        return image
    }
}
