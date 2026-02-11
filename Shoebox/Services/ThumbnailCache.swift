// Copyright 2026 Link Dupont
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import AppKit
import CryptoKit

actor ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSURL, NSImage>()
    private var inFlightTasks: [URL: Task<NSImage?, Never>] = [:]
    private let diskCacheURL: URL

    init() {
        cache.countLimit = 500
        cache.totalCostLimit = 150 * 1024 * 1024 // 150 MB

        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier ?? "Shoebox"
        diskCacheURL = caches.appendingPathComponent(bundleID).appendingPathComponent("Thumbnails")

        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }

    // MARK: - Public

    func thumbnail(for url: URL, size: CGSize) async -> NSImage? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }

        if let existingTask = inFlightTasks[url] {
            return await existingTask.value
        }

        let task = Task<NSImage?, Never> {
            if let diskImage = loadFromDisk(for: url, size: size) {
                return diskImage
            }
            guard let generated = await generateThumbnail(for: url, size: size) else {
                return nil
            }
            saveToDisk(generated, for: url, size: size)
            return generated
        }

        inFlightTasks[url] = task
        let result = await task.value
        inFlightTasks.removeValue(forKey: url)

        if let image = result {
            cache.setObject(image, forKey: url as NSURL)
        }

        return result
    }

    func clearCache() {
        cache.removeAllObjects()
        try? FileManager.default.removeItem(at: diskCacheURL)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }

    // MARK: - Disk Cache

    private func cacheFileURL(for url: URL, size: CGSize) -> URL {
        let key = "\(url.absoluteString)|\(Int(size.width))x\(Int(size.height))"
        let hash = SHA256.hash(data: Data(key.utf8))
        let name = hash.compactMap { String(format: "%02x", $0) }.joined()
        return diskCacheURL.appendingPathComponent(name + ".jpg")
    }

    private func loadFromDisk(for url: URL, size: CGSize) -> NSImage? {
        let fileURL = cacheFileURL(for: url, size: size)
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return nil }

        let sourceDate = (try? fm.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
        let cacheDate = (try? fm.attributesOfItem(atPath: fileURL.path))?[.modificationDate] as? Date
        if let src = sourceDate, let cached = cacheDate, src > cached {
            return nil
        }

        return NSImage(contentsOf: fileURL)
    }

    private func saveToDisk(_ image: NSImage, for url: URL, size: CGSize) {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
        else { return }

        let fileURL = cacheFileURL(for: url, size: size)
        try? jpeg.write(to: fileURL, options: .atomic)
    }

    // MARK: - Thumbnail Generation

    private func generateThumbnail(for url: URL, size: CGSize) async -> NSImage? {
        let maxDimension = max(size.width, size.height) * 2
        guard let cgImage = ThumbnailGenerator.createThumbnail(from: url, maxPixelSize: maxDimension) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
