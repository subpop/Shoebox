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
        collageCache.removeAllObjects()
        try? FileManager.default.removeItem(at: diskCacheURL)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }

    // MARK: - Composite Collage

    private let collageCache = NSCache<NSString, NSImage>()

    /// Generates a single composite collage image from the given sample photos,
    /// arranged in a `gridSize x gridSize` grid with focus-point-aware cropping.
    /// The result is cached in memory and on disk.
    func compositeCollage(
        samples: [SamplePhoto],
        gridSize: Int,
        totalSize: CGSize
    ) async -> NSImage? {
        guard !samples.isEmpty else { return nil }

        let cacheKey = collageCacheKey(samples: samples, gridSize: gridSize, totalSize: totalSize)

        // In-memory hit
        if let cached = collageCache.object(forKey: cacheKey as NSString) {
            return cached
        }

        // Disk hit
        let diskURL = collageDiskURL(for: cacheKey)
        if FileManager.default.fileExists(atPath: diskURL.path),
           let diskImage = NSImage(contentsOf: diskURL) {
            collageCache.setObject(diskImage, forKey: cacheKey as NSString)
            return diskImage
        }

        // Generate: load individual thumbnails then composite
        let cellCount = gridSize * gridSize
        let cellWidth = totalSize.width / CGFloat(gridSize)
        let cellHeight = totalSize.height / CGFloat(gridSize)
        let cellSize = CGSize(width: cellWidth, height: cellHeight)

        // Load all needed thumbnails concurrently
        var thumbnails: [(index: Int, image: NSImage, focusPoint: CGPoint?)] = []
        let displaySamples = Array(samples.prefix(cellCount))
        await withTaskGroup(of: (Int, NSImage?, CGPoint?).self) { group in
            for i in 0..<cellCount {
                let sample = displaySamples[i % displaySamples.count]
                group.addTask {
                    let img = await self.thumbnail(for: sample.url, size: cellSize)
                    return (i, img, sample.focusPoint)
                }
            }
            for await (index, image, fp) in group {
                if let image {
                    thumbnails.append((index, image, fp))
                }
            }
        }
        thumbnails.sort { $0.index < $1.index }

        guard !thumbnails.isEmpty else { return nil }

        // Composite into a single bitmap
        let composite = NSImage(size: totalSize)
        composite.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high

        for entry in thumbnails {
            let row = entry.index / gridSize
            let col = entry.index % gridSize
            let cellOrigin = CGPoint(
                x: CGFloat(col) * cellWidth,
                // NSImage draws with bottom-left origin
                y: totalSize.height - CGFloat(row + 1) * cellHeight
            )
            let cellRect = CGRect(origin: cellOrigin, size: cellSize)

            let imgSize = entry.image.size
            let scale = max(cellWidth / imgSize.width, cellHeight / imgSize.height)
            let scaledW = imgSize.width * scale
            let scaledH = imgSize.height * scale

            // Convert Vision focus point (bottom-left origin) to drawing coords
            let fpX = entry.focusPoint?.x ?? 0.5
            let fpY = entry.focusPoint?.y ?? 0.5

            // Offset so the focus point sits at the center of the cell
            let rawOffsetX = (0.5 - fpX) * scaledW
            let rawOffsetY = (0.5 - fpY) * scaledH

            // Clamp so we don't expose empty space
            let maxOffsetX = (scaledW - cellWidth) / 2
            let maxOffsetY = (scaledH - cellHeight) / 2
            let clampedX = max(-maxOffsetX, min(maxOffsetX, rawOffsetX))
            let clampedY = max(-maxOffsetY, min(maxOffsetY, rawOffsetY))

            // Source rect in the original image that maps into this cell
            let drawOriginX = cellOrigin.x - (scaledW - cellWidth) / 2 + clampedX
            let drawOriginY = cellOrigin.y - (scaledH - cellHeight) / 2 + clampedY
            let drawRect = CGRect(x: drawOriginX, y: drawOriginY,
                                  width: scaledW, height: scaledH)

            // Clip to cell bounds and draw
            NSGraphicsContext.current?.cgContext.saveGState()
            NSBezierPath(rect: cellRect).addClip()
            entry.image.draw(in: drawRect,
                             from: NSRect(origin: .zero, size: imgSize),
                             operation: .sourceOver,
                             fraction: 1.0)
            NSGraphicsContext.current?.cgContext.restoreGState()
        }

        composite.unlockFocus()

        // Cache in memory and on disk
        collageCache.setObject(composite, forKey: cacheKey as NSString)
        saveCollageToDisk(composite, url: diskURL)

        return composite
    }

    private func collageCacheKey(samples: [SamplePhoto], gridSize: Int, totalSize: CGSize) -> String {
        let urlPart = samples.map { $0.url.absoluteString }.joined(separator: "|")
        let fpPart = samples.map { s in
            if let fp = s.focusPoint { return "\(fp.x),\(fp.y)" } else { return "nil" }
        }.joined(separator: "|")
        return "\(urlPart)|\(fpPart)|\(gridSize)|\(Int(totalSize.width))x\(Int(totalSize.height))"
    }

    private func collageDiskURL(for key: String) -> URL {
        let name = Data(key.utf8).sha256Hex
        return diskCacheURL.appendingPathComponent("collage-\(name).jpg")
    }

    private func saveCollageToDisk(_ image: NSImage, url: URL) {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
        else { return }
        try? jpeg.write(to: url, options: .atomic)
    }

    // MARK: - Disk Cache

    private func cacheFileURL(for url: URL, size: CGSize) -> URL {
        let key = "\(url.absoluteString)|\(Int(size.width))x\(Int(size.height))"
        let name = Data(key.utf8).sha256Hex
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
