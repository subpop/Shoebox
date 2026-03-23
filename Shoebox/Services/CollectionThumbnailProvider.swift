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

import Foundation
import CoreGraphics

/// A sampled photo URL paired with its SmartCropper focus point.
struct SamplePhoto: Identifiable, Equatable {
    let url: URL
    /// Normalized focus point in Vision coordinates (origin at bottom-left, 0…1).
    /// `nil` until the focus point has been computed.
    var focusPoint: CGPoint?

    var id: String { url.absoluteString }

    init(url: URL, focusPoint: CGPoint? = nil) {
        self.url = url
        self.focusPoint = focusPoint
    }
}

/// Provides a small sample of image URLs for each collection, used to build
/// collage previews in the sidebar. Caches results by collection ID and
/// invalidates when the photo count changes. Computes SmartCropper focus
/// points in the background.
@MainActor
class CollectionThumbnailProvider: ObservableObject {
    static let shared = CollectionThumbnailProvider()

    /// Maximum number of sample images to return per collection.
    static let maxSampleCount = 9

    private struct CacheEntry {
        var samples: [SamplePhoto]
        let photoCount: Int
    }

    private var cache: [UUID: CacheEntry] = [:]
    private var focusPointTasks: [UUID: Task<Void, Never>] = [:]

    /// Returns up to `maxSampleCount` sample photos from the given collection,
    /// resolving the security-scoped bookmark to access the folder.
    func samples(
        for collection: PhotoCollection,
        using manager: CollectionManager
    ) -> [SamplePhoto] {
        // Return cached result if photo count hasn't changed
        if let entry = cache[collection.id], entry.photoCount == collection.photoCount {
            return entry.samples
        }

        guard let url = manager.resolveURL(for: collection) else { return [] }

        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let allURLs = ShoeboxKit.imageURLs(
            in: url,
            recursive: collection.recurseSubdirectories
        )

        let sampleURLs = Self.spreadSample(from: allURLs, count: Self.maxSampleCount)
        let samples = sampleURLs.map { SamplePhoto(url: $0) }

        let entry = CacheEntry(samples: samples, photoCount: collection.photoCount)
        cache[collection.id] = entry

        computeFocusPoints(for: collection.id, urls: sampleURLs)

        return samples
    }

    /// Returns up to `maxSampleCount` sample photos from the user's favorites.
    func samples(
        forFavoriteIDs favoriteIDs: Set<String>,
        using manager: CollectionManager
    ) -> [SamplePhoto] {
        let cacheID = CollectionManager.favoritesCollectionID

        if let entry = cache[cacheID], entry.photoCount == favoriteIDs.count {
            return entry.samples
        }

        // Access all collections to find favorite files
        let sources = manager.startAccessingAll()
        var favoriteURLs: [URL] = []

        for source in sources {
            let urls = ShoeboxKit.imageURLs(in: source.url, recursive: source.recursive)
            let matching = urls.filter { favoriteIDs.contains($0.absoluteString) }
            favoriteURLs.append(contentsOf: matching)
        }

        let sampleURLs = Self.spreadSample(from: favoriteURLs, count: Self.maxSampleCount)
        let samples = sampleURLs.map { SamplePhoto(url: $0) }

        let entry = CacheEntry(samples: samples, photoCount: favoriteIDs.count)
        cache[cacheID] = entry

        computeFocusPoints(for: cacheID, urls: sampleURLs)

        return samples
    }

    /// Invalidates the cached sample for a specific collection.
    func invalidate(collectionID: UUID) {
        focusPointTasks[collectionID]?.cancel()
        focusPointTasks.removeValue(forKey: collectionID)
        cache.removeValue(forKey: collectionID)
    }

    /// Invalidates all cached samples.
    func invalidateAll() {
        for task in focusPointTasks.values { task.cancel() }
        focusPointTasks.removeAll()
        cache.removeAll()
    }

    // MARK: - Focus Point Computation

    /// Computes SmartCropper focus points for the given URLs in the background,
    /// updating the cache as results arrive.
    private func computeFocusPoints(for collectionID: UUID, urls: [URL]) {
        focusPointTasks[collectionID]?.cancel()

        focusPointTasks[collectionID] = Task.detached(priority: .background) {
            for url in urls {
                if Task.isCancelled { return }
                // Yield to avoid starving the image indexer, which also
                // uses Vision on the cooperative thread pool.
                await Task.yield()

                guard let cgImage = ThumbnailGenerator.createThumbnail(
                    from: url,
                    maxPixelSize: 200
                ) else { continue }

                let point = SmartCropper.focusPoint(for: cgImage)

                await MainActor.run {
                    guard var entry = self.cache[collectionID] else { return }
                    if let idx = entry.samples.firstIndex(where: { $0.url == url }) {
                        entry.samples[idx].focusPoint = point
                        self.cache[collectionID] = entry
                        self.objectWillChange.send()
                    }
                }
            }
        }
    }

    // MARK: - Sampling

    /// Picks up to `count` items spread evenly across the source array.
    /// This gives a representative sample rather than just the first N items.
    private static func spreadSample(from urls: [URL], count: Int) -> [URL] {
        guard !urls.isEmpty else { return [] }
        guard urls.count > count else { return urls }

        var result: [URL] = []
        let step = Double(urls.count) / Double(count)
        for i in 0..<count {
            let index = Int(Double(i) * step)
            result.append(urls[index])
        }
        return result
    }
}
