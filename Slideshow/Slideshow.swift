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
import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct SlideshowEntry: TimelineEntry {
    let date: Date
    let imagePath: String?
    let collectionName: String
    let photoIndex: Int
    let totalPhotos: Int
    let focusPoint: CGPoint?

    static func empty(collectionName: String = "Photos") -> SlideshowEntry {
        SlideshowEntry(
            date: Date(),
            imagePath: nil,
            collectionName: collectionName,
            photoIndex: 0,
            totalPhotos: 0,
            focusPoint: nil
        )
    }
}

// MARK: - Timeline Provider

struct SlideshowProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SlideshowEntry {
        .empty()
    }

    func snapshot(for configuration: SelectCollectionIntent, in context: Context) async -> SlideshowEntry {
        .empty(collectionName: configuration.collection?.name ?? "Photos")
    }

    func timeline(for configuration: SelectCollectionIntent, in context: Context) async -> Timeline<SlideshowEntry> {
        let collectionID: UUID?
        let collectionName: String

        if let entity = configuration.collection {
            collectionID = entity.id
            collectionName = entity.name
        } else {
            // Fall back to the first available collection
            let defaults = ShoeboxKit.sharedDefaults
            if let data = defaults.data(forKey: ShoeboxKit.collectionsKey),
               let collections = try? JSONDecoder().decode([PhotoCollection].self, from: data),
               let first = collections.first {
                collectionID = first.id
                collectionName = first.name
            } else {
                collectionID = nil
                collectionName = "Photos"
            }
        }

        guard let id = collectionID,
              let thumbnailsDir = ShoeboxKit.widgetThumbnailsURL(forCollectionID: id) else {
            return Timeline(entries: [.empty(collectionName: "No Collection")], policy: .after(Date().addingTimeInterval(3600)))
        }

        // Load focus-point manifest
        let focusPoints = Self.loadFocusPoints(from: thumbnailsDir)

        var imagePaths: [String] = []
        if let files = try? FileManager.default.contentsOfDirectory(at: thumbnailsDir, includingPropertiesForKeys: nil) {
            imagePaths = files
                .filter { ShoeboxKit.imageExtensions.contains($0.pathExtension.lowercased()) }
                .map { $0.path }
                .sorted()
        }

        guard !imagePaths.isEmpty else {
            return Timeline(entries: [.empty(collectionName: collectionName)], policy: .after(Date().addingTimeInterval(3600)))
        }

        var entries: [SlideshowEntry] = []
        let now = Date()
        let intervalSeconds: TimeInterval = configuration.interval.seconds

        let shuffled = imagePaths.shuffled()
        for i in 0..<min(shuffled.count, 24) {
            let entryDate = now.addingTimeInterval(Double(i) * intervalSeconds)
            let filename = URL(fileURLWithPath: shuffled[i]).lastPathComponent
            let entry = SlideshowEntry(
                date: entryDate,
                imagePath: shuffled[i],
                collectionName: collectionName,
                photoIndex: i,
                totalPhotos: imagePaths.count,
                focusPoint: focusPoints[filename]
            )
            entries.append(entry)
        }

        let refreshDate = now.addingTimeInterval(Double(entries.count) * intervalSeconds)
        return Timeline(entries: entries, policy: .after(refreshDate))
    }

    /// Reads the focus-point manifest written by the main app during export.
    private static func loadFocusPoints(from thumbnailsDir: URL) -> [String: CGPoint] {
        let manifestURL = thumbnailsDir.appendingPathComponent(ShoeboxKit.focusPointsManifestName)
        guard let data = try? Data(contentsOf: manifestURL),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: [String: CGFloat]]
        else { return [:] }

        var result: [String: CGPoint] = [:]
        for (filename, coords) in dict {
            if let x = coords["x"], let y = coords["y"] {
                result[filename] = CGPoint(x: x, y: y)
            }
        }
        return result
    }
}

// MARK: - Widget View

struct SlideshowEntryView : View {
    var entry: SlideshowProvider.Entry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let imagePath = entry.imagePath,
               let image = NSImage(contentsOfFile: imagePath) {
                GeometryReader { geo in
                    let imgSize = image.size
                    let widgetSize = geo.size
                    let scale = max(widgetSize.width / imgSize.width,
                                    widgetSize.height / imgSize.height)
                    let scaledW = imgSize.width * scale
                    let scaledH = imgSize.height * scale
                    // Flip Vision Y (bottom-up) to SwiftUI Y (top-down)
                    let fpX = entry.focusPoint?.x ?? 0.5
                    let fpY = 1.0 - (entry.focusPoint?.y ?? 0.5)
                    // Offset so the focus point lands at the center of the widget
                    let rawOffsetX = (0.5 - fpX) * scaledW
                    let rawOffsetY = (0.5 - fpY) * scaledH
                    // Clamp so we never reveal empty space beyond the image edges
                    let maxOffsetX = (scaledW - widgetSize.width) / 2
                    let maxOffsetY = (scaledH - widgetSize.height) / 2
                    let offsetX = min(max(rawOffsetX, -maxOffsetX), maxOffsetX)
                    let offsetY = min(max(rawOffsetY, -maxOffsetY), maxOffsetY)

                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .offset(x: offsetX, y: offsetY)
                        .frame(width: widgetSize.width, height: widgetSize.height)
                        .clipped()
                }
            } else {
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.3),
                        Color.purple.opacity(0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.stack")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Open Shoebox to\nadd photos")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }

            // Collection name overlay
            if entry.imagePath != nil {
                HStack {
                    Image(systemName: "photo.stack")
                        .font(.caption2)
                    Text(entry.collectionName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 2)
                .padding(8)
            }
        }
    }
}

// MARK: - Widget Definition

struct Slideshow: Widget {
    let kind: String = "Slideshow"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectCollectionIntent.self, provider: SlideshowProvider()) { entry in
            SlideshowEntryView(entry: entry)
                .containerBackground(for: .widget) {}
        }
        .configurationDisplayName("Slideshow")
        .description("Shows a rotating slideshow from a photo collection.")
        .supportedFamilies(
            [.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge]
        )
        .contentMarginsDisabled()
        .containerBackgroundRemovable(false)
    }
}
// MARK: - Preview

#Preview("Slideshow (empty)", as: .systemMedium) {
    Slideshow()
} timeline: {
    SlideshowEntry.empty()
}

#Preview("Slideshow (photo)", as: .systemMedium) {
    Slideshow()
} timeline: {
    SlideshowEntry(
        date: .now,
        imagePath: nil,
        collectionName: "Vacation",
        photoIndex: 3,
        totalPhotos: 42,
        focusPoint: nil
    )
}

