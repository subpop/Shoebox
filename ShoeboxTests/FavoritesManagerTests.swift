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

import Testing
import Foundation
@testable import Shoebox

struct FavoritesManagerTests {
    /// Creates a fresh UserDefaults suite that is empty and isolated per test.
    private func makeDefaults() -> UserDefaults {
        let suiteName = "FavoritesManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makePhoto(path: String = "/photos/test.jpg") -> PhotoItem {
        PhotoItem(url: URL(fileURLWithPath: path))
    }

    // MARK: - Toggle & Query

    // Verify a new manager starts with no favorites.
    @Test func initiallyEmpty() {
        let manager = FavoritesManager(defaults: makeDefaults())
        #expect(manager.favoriteIDs.isEmpty)
        #expect(manager.count == 0)
    }

    // Verify toggling a photo adds it, and toggling again removes it.
    @Test func toggleAddsAndRemovesFavorite() {
        let manager = FavoritesManager(defaults: makeDefaults())
        let photo = makePhoto()

        manager.toggleFavorite(photo)
        #expect(manager.isFavorite(photo))
        #expect(manager.count == 1)

        manager.toggleFavorite(photo)
        #expect(!manager.isFavorite(photo))
        #expect(manager.count == 0)
    }

    // Verify multiple distinct photos can be favorited independently.
    @Test func multiplePhotos() {
        let manager = FavoritesManager(defaults: makeDefaults())
        let photo1 = makePhoto(path: "/photos/a.jpg")
        let photo2 = makePhoto(path: "/photos/b.jpg")

        manager.toggleFavorite(photo1)
        manager.toggleFavorite(photo2)

        #expect(manager.count == 2)
        #expect(manager.isFavorite(photo1))
        #expect(manager.isFavorite(photo2))
    }

    // MARK: - Persistence

    // Verify favorites survive creating a new manager instance with the same defaults.
    @Test func persistsAcrossInstances() {
        let defaults = makeDefaults()
        let photo = makePhoto()

        let manager1 = FavoritesManager(defaults: defaults)
        manager1.toggleFavorite(photo)

        let manager2 = FavoritesManager(defaults: defaults)
        #expect(manager2.isFavorite(photo))
        #expect(manager2.count == 1)
    }

    // MARK: - removeFavorites(underPath:)

    // Verify favorites under a given directory path are removed while others are kept.
    @Test func removeFavoritesUnderPath() {
        let manager = FavoritesManager(defaults: makeDefaults())
        let inside = makePhoto(path: "/photos/vacation/beach.jpg")
        let outside = makePhoto(path: "/photos/work/report.jpg")

        manager.toggleFavorite(inside)
        manager.toggleFavorite(outside)
        #expect(manager.count == 2)

        manager.removeFavorites(underPath: "/photos/vacation")

        #expect(!manager.isFavorite(inside))
        #expect(manager.isFavorite(outside))
        #expect(manager.count == 1)
    }

    // Verify removal works the same when the directory path has a trailing slash.
    @Test func removeFavoritesUnderPathWithTrailingSlash() {
        let manager = FavoritesManager(defaults: makeDefaults())
        let photo = makePhoto(path: "/photos/vacation/beach.jpg")
        manager.toggleFavorite(photo)

        manager.removeFavorites(underPath: "/photos/vacation/")

        #expect(!manager.isFavorite(photo))
    }

    // Verify no favorites are removed when the path doesn't match any.
    @Test func removeFavoritesUnderPathNoMatch() {
        let defaults = makeDefaults()
        let manager = FavoritesManager(defaults: defaults)
        let photo = makePhoto(path: "/photos/keep.jpg")
        manager.toggleFavorite(photo)

        manager.removeFavorites(underPath: "/other")

        #expect(manager.isFavorite(photo))
        #expect(manager.count == 1)
    }

    // MARK: - pruneStale

    // Verify pruning removes favorites whose IDs are no longer in the valid set.
    @Test func pruneStaleRemovesInvalidIDs() {
        let manager = FavoritesManager(defaults: makeDefaults())
        let keep = makePhoto(path: "/photos/keep.jpg")
        let stale = makePhoto(path: "/photos/stale.jpg")

        manager.toggleFavorite(keep)
        manager.toggleFavorite(stale)
        #expect(manager.count == 2)

        manager.pruneStale(validIDs: Set([keep.id]))

        #expect(manager.isFavorite(keep))
        #expect(!manager.isFavorite(stale))
        #expect(manager.count == 1)
    }

    // Verify pruning is a no-op when all favorites are still valid.
    @Test func pruneStaleWithAllValid() {
        let manager = FavoritesManager(defaults: makeDefaults())
        let photo = makePhoto()
        manager.toggleFavorite(photo)

        manager.pruneStale(validIDs: Set([photo.id]))

        #expect(manager.isFavorite(photo))
        #expect(manager.count == 1)
    }
}
