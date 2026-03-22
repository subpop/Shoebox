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

import SwiftUI

/// A collage of square-cropped photo thumbnails arranged in a tight grid.
/// Used as a background for sidebar collection items in both list and grid modes.
struct CollageView: View {
    let imageURLs: [URL]
    var gridSize: Int = 2
    var thumbnailSize: CGSize = CGSize(width: 150, height: 150)
    /// Changing this value forces all cells to reload their thumbnails.
    var refreshID: Int = 0

    /// How many cells the grid contains.
    private var cellCount: Int { gridSize * gridSize }

    /// The URLs to actually display, capped to the grid capacity.
    private var displayURLs: [URL] {
        Array(imageURLs.prefix(cellCount))
    }

    var body: some View {
        if displayURLs.isEmpty {
            Rectangle().fill(.quaternary.opacity(0.5))
        } else {
            GeometryReader { geometry in
                let cellWidth = geometry.size.width / CGFloat(gridSize)
                let cellHeight = geometry.size.height / CGFloat(gridSize)

                VStack(spacing: 0) {
                    ForEach(0..<gridSize, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<gridSize, id: \.self) { col in
                                let index = row * gridSize + col
                                let url = displayURLs[index % displayURLs.count]
                                CollageCellView(url: url, thumbnailSize: thumbnailSize, refreshID: refreshID)
                                    .frame(width: cellWidth, height: cellHeight)
                                    .clipped()
                            }
                        }
                    }
                }
            }
        }
    }
}

/// A single cell in the collage that loads a thumbnail asynchronously and
/// displays it with aspect-fill cropping.
private struct CollageCellView: View {
    let url: URL
    let thumbnailSize: CGSize
    var refreshID: Int = 0
    @State private var image: NSImage?

    /// Combined identity so the task re-fires on URL change or cache clear.
    private var taskID: String {
        "\(url.absoluteString)-\(refreshID)"
    }

    var body: some View {
        ZStack {
            Rectangle().fill(.quaternary.opacity(0.3))

            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
        }
        .task(id: taskID) {
            image = nil
            image = await ThumbnailCache.shared.thumbnail(
                for: url,
                size: thumbnailSize
            )
        }
    }
}

// MARK: - Previews

#Preview("Collage 2x2") {
    CollageView(
        imageURLs: [
            URL(fileURLWithPath: "/System/Library/Desktop Pictures/.thumbnails/Dome Light.heic"),
            URL(fileURLWithPath: "/System/Library/Desktop Pictures/.thumbnails/Dome Dark.heic"),
            URL(fileURLWithPath: "/System/Library/Desktop Pictures/.thumbnails/Tree Dark.heic"),
            URL(fileURLWithPath: "/System/Library/Desktop Pictures/.thumbnails/Big Sur Coastline.heic"),
        ],
        gridSize: 2
    )
    .frame(width: 200, height: 200)
    .clipShape(RoundedRectangle(cornerRadius: 12))
}

#Preview("Collage 3x3") {
    CollageView(
        imageURLs: [
            URL(fileURLWithPath: "/System/Library/Desktop Pictures/.thumbnails/Dome Light.heic"),
            URL(fileURLWithPath: "/System/Library/Desktop Pictures/.thumbnails/Dome Dark.heic"),
            URL(fileURLWithPath: "/System/Library/Desktop Pictures/.thumbnails/Tree Dark.heic"),
            URL(fileURLWithPath: "/System/Library/Desktop Pictures/.thumbnails/Big Sur Coastline.heic"),
        ],
        gridSize: 3
    )
    .frame(width: 300, height: 300)
    .clipShape(RoundedRectangle(cornerRadius: 12))
}

#Preview("Collage - Empty") {
    CollageView(imageURLs: [], gridSize: 2)
        .frame(width: 200, height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 12))
}
