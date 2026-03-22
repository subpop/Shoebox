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

/// Provides a small sample of image URLs for each collection, used to build
/// collage previews in the sidebar. Caches results by collection ID and
/// invalidates when the photo count changes.
@MainActor
class CollectionThumbnailProvider: ObservableObject {
    static let shared = CollectionThumbnailProvider()

    /// Maximum number of sample images to return per collection.
    static let maxSampleCount = 9

    private struct CacheEntry {
        let urls: [URL]
        let photoCount: Int
    }

    private var cache: [UUID: CacheEntry] = [:]

    /// Returns up to `maxSampleCount` image URLs from the given collection,
    /// resolving the security-scoped bookmark to access the folder.
    func sampleURLs(
        for collection: PhotoCollection,
        using manager: CollectionManager
    ) -> [URL] {
        // Return cached result if photo count hasn't changed
        if let entry = cache[collection.id], entry.photoCount == collection.photoCount {
            return entry.urls
        }

        guard let url = manager.resolveURL(for: collection) else { return [] }

        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let allURLs = ShoeboxKit.imageURLs(
            in: url,
            recursive: collection.recurseSubdirectories
        )

        // Take a deterministic sample: spread evenly across the collection
        let sample = Self.spreadSample(from: allURLs, count: Self.maxSampleCount)

        let entry = CacheEntry(urls: sample, photoCount: collection.photoCount)
        cache[collection.id] = entry

        return sample
    }

    /// Returns up to `maxSampleCount` image URLs from the user's favorites.
    func sampleURLs(
        forFavoriteIDs favoriteIDs: Set<String>,
        using manager: CollectionManager
    ) -> [URL] {
        let cacheID = CollectionManager.favoritesCollectionID

        if let entry = cache[cacheID], entry.photoCount == favoriteIDs.count {
            return entry.urls
        }

        // Access all collections to find favorite files
        let sources = manager.startAccessingAll()
        var favoriteURLs: [URL] = []

        for source in sources {
            let urls = ShoeboxKit.imageURLs(in: source.url, recursive: source.recursive)
            let matching = urls.filter { favoriteIDs.contains($0.absoluteString) }
            favoriteURLs.append(contentsOf: matching)
        }

        let sample = Self.spreadSample(from: favoriteURLs, count: Self.maxSampleCount)

        let entry = CacheEntry(urls: sample, photoCount: favoriteIDs.count)
        cache[cacheID] = entry

        return sample
    }

    /// Invalidates the cached sample for a specific collection.
    func invalidate(collectionID: UUID) {
        cache.removeValue(forKey: collectionID)
    }

    /// Invalidates all cached samples.
    func invalidateAll() {
        cache.removeAll()
    }

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
