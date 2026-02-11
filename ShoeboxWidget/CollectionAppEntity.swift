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

import AppIntents
import Foundation

struct CollectionAppEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Photo Collection"

    static var defaultQuery = CollectionEntityQuery()

    var id: UUID
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }

    init(from collection: PhotoCollection) {
        self.id = collection.id
        self.name = collection.name
    }
}

struct CollectionEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [CollectionAppEntity] {
        let all = Self.loadAllEntities()
        return all.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [CollectionAppEntity] {
        Self.loadAllEntities()
    }

    func defaultResult() async -> CollectionAppEntity? {
        let all = Self.loadAllEntities()
        let defaults = ShoeboxKit.sharedDefaults
        if let savedID = defaults.string(forKey: ShoeboxKit.selectedCollectionIDKey),
           let uuid = UUID(uuidString: savedID),
           let match = all.first(where: { $0.id == uuid }) {
            return match
        }
        return all.first
    }

    /// Returns the Favorites entity followed by all folder-based collection entities.
    private static func loadAllEntities() -> [CollectionAppEntity] {
        var entities: [CollectionAppEntity] = []

        // Include Favorites if there are any favorited photos
        let defaults = ShoeboxKit.sharedDefaults
        let favoriteCount = (defaults.stringArray(forKey: ShoeboxKit.favoritesKey) ?? []).count
        if favoriteCount > 0 {
            entities.append(CollectionAppEntity(
                id: ShoeboxKit.favoritesCollectionID,
                name: "Favorites"
            ))
        }

        if let data = defaults.data(forKey: ShoeboxKit.collectionsKey),
           let collections = try? JSONDecoder().decode([PhotoCollection].self, from: data) {
            entities.append(contentsOf: collections.map { CollectionAppEntity(from: $0) })
        }

        return entities
    }
}
