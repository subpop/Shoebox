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

enum ShoeboxKit {
    /// Resolved from Info.plist; derived from the DEVELOPMENT_TEAM build setting.
    static let appGroupIdentifier = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as! String
    static let collectionsKey = "savedCollections"
    static let selectedCollectionIDKey = "selectedCollectionID"
    static let selectedCollectionKey = "selectedWidgetCollection"
    static let thumbnailsDirectoryName = "WidgetThumbnails"
    static let focusPointsManifestName = "focus_points.json"
    static let favoritesKey = "favoritePhotos"
    static let lockPasswordHashKey = "lockPasswordHash"
    static let lockMethodKey = "lockMethod"
    static let favoritesCollectionID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "heic", "heif",
        "tiff", "tif", "bmp", "webp"
    ]

    static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    /// Base directory for all widget thumbnails.
    /// Falls back to Application Support if the App Group container is unavailable.
    static var widgetThumbnailsURL: URL? {
        if let containerURL = sharedContainerURL {
            return containerURL.appendingPathComponent(thumbnailsDirectoryName)
        }
        // Fallback for development without a provisioned App Group
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let fallback = appSupport.appendingPathComponent("Shoebox").appendingPathComponent(thumbnailsDirectoryName)
            return fallback
        }
        return nil
    }

    /// Per-collection thumbnail subdirectory: `WidgetThumbnails/{collectionID}/`
    static func widgetThumbnailsURL(forCollectionID id: UUID) -> URL? {
        widgetThumbnailsURL?.appendingPathComponent(id.uuidString)
    }

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    /// Load saved collections from shared UserDefaults.
    static func loadCollections() -> [PhotoCollection] {
        guard let data = sharedDefaults.data(forKey: collectionsKey),
              let decoded = try? JSONDecoder().decode([PhotoCollection].self, from: data)
        else { return [] }
        return decoded
    }

    static func photoCountLabel(_ count: Int) -> String {
        "\(count) photo\(count == 1 ? "" : "s")"
    }

    /// Enumerates image file URLs in a directory, optionally recursing into subdirectories.
    static func imageURLs(
        in directory: URL,
        recursive: Bool = true,
        resourceKeys: [URLResourceKey]? = nil
    ) -> [URL] {
        var options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles]
        if !recursive {
            options.insert(.skipsSubdirectoryDescendants)
        }
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: resourceKeys,
            options: options
        ) else { return [] }

        var urls: [URL] = []
        while let fileURL = enumerator.nextObject() as? URL {
            if imageExtensions.contains(fileURL.pathExtension.lowercased()) {
                urls.append(fileURL)
            }
        }
        return urls
    }
}
