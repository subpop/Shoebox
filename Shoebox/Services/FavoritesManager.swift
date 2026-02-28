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

class FavoritesManager: ObservableObject {
    @Published private(set) var favoriteIDs: Set<String> = []

    private let defaults: UserDefaults
    private static let favoritesKey = ShoeboxKit.favoritesKey

    var count: Int { favoriteIDs.count }

    init(defaults: UserDefaults = ShoeboxKit.sharedDefaults) {
        self.defaults = defaults
        loadFavorites()
    }

    func isFavorite(_ photo: PhotoItem) -> Bool {
        favoriteIDs.contains(photo.id)
    }

    func toggleFavorite(_ photo: PhotoItem) {
        if favoriteIDs.contains(photo.id) {
            favoriteIDs.remove(photo.id)
        } else {
            favoriteIDs.insert(photo.id)
        }
        saveFavorites()
    }

    /// Remove all favorites whose file paths fall under the given directory.
    func removeFavorites(underPath directoryPath: String) {
        let prefix = directoryPath.hasSuffix("/") ? directoryPath : directoryPath + "/"
        let before = favoriteIDs.count
        favoriteIDs = favoriteIDs.filter { id in
            guard let url = URL(string: id) else { return true }
            return !url.path.hasPrefix(prefix)
        }
        if favoriteIDs.count != before {
            saveFavorites()
        }
    }

    /// Remove any favorited IDs that no longer appear in the given set of valid IDs.
    func pruneStale(validIDs: Set<String>) {
        let before = favoriteIDs.count
        favoriteIDs = favoriteIDs.intersection(validIDs)
        if favoriteIDs.count != before {
            saveFavorites()
        }
    }

    // MARK: - Persistence

    private func saveFavorites() {
        let array = Array(favoriteIDs)
        defaults.set(array, forKey: Self.favoritesKey)
    }

    private func loadFavorites() {
        if let array = defaults.stringArray(forKey: Self.favoritesKey) {
            favoriteIDs = Set(array)
        }
    }
}
