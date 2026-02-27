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
import AppKit

@MainActor
class PhotoLoader: ObservableObject {
    @Published var photos: [PhotoItem] = []
    @Published var isLoading = false

    private var currentTask: Task<Void, Never>?

    func loadPhotos(from url: URL, recursive: Bool = true) {
        currentTask?.cancel()

        isLoading = true
        photos = []

        currentTask = Task {
            let items = await scanFolder(url: url, recursive: recursive)
            if !Task.isCancelled {
                photos = items
                isLoading = false
            }
        }
    }

    func loadFavorites(from sources: [(url: URL, recursive: Bool)], matching favoriteIDs: Set<String>) {
        currentTask?.cancel()

        guard !favoriteIDs.isEmpty else {
            photos = []
            isLoading = false
            return
        }

        isLoading = true
        photos = []

        currentTask = Task { [favoriteIDs] in
            // Build results per source locally to avoid mutating a captured var from concurrently executing code.
            var perSourceResults: [[PhotoItem]] = []
            perSourceResults.reserveCapacity(sources.count)

            for source in sources {
                if Task.isCancelled { return }
                let items = await scanFolder(url: source.url, recursive: source.recursive)
                let favorites = items.filter { favoriteIDs.contains($0.id) }
                // Append into a local array owned by this task scope; not captured by any @Sendable closure.
                perSourceResults.append(favorites)
            }

            if Task.isCancelled { return }

            // Flatten immutably and sort before hopping to the main actor.
            let combined = perSourceResults.flatMap { $0 }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

            photos = combined
            isLoading = false
        }
    }

    func clear() {
        currentTask?.cancel()
        photos = []
        isLoading = false
    }

    nonisolated private func scanFolder(url: URL, recursive: Bool) async -> [PhotoItem] {
        let urls = ShoeboxKit.imageURLs(
            in: url,
            recursive: recursive,
            resourceKeys: [.contentModificationDateKey, .fileSizeKey]
        )

        var items = urls.map { PhotoItem(url: $0) }
        items.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return items
    }
}

