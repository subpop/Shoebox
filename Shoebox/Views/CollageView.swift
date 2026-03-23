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

/// A collage of photo thumbnails arranged in a tight grid.
/// Each cell uses the SmartCropper focus point to align the most interesting
/// part of the image within the square crop.
struct CollageView: View {
    let samples: [SamplePhoto]
    var gridSize: Int = 2
    var thumbnailSize: CGSize = CGSize(width: 150, height: 150)
    /// Changing this value forces all cells to reload their thumbnails.
    var refreshID: Int = 0

    /// How many cells the grid contains.
    private var cellCount: Int { gridSize * gridSize }

    /// The samples to actually display, capped to the grid capacity.
    private var displaySamples: [SamplePhoto] {
        Array(samples.prefix(cellCount))
    }

    var body: some View {
        if displaySamples.isEmpty {
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
                                let sample = displaySamples[index % displaySamples.count]
                                CollageCellView(
                                    url: sample.url,
                                    focusPoint: sample.focusPoint,
                                    thumbnailSize: thumbnailSize,
                                    refreshID: refreshID
                                )
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
/// displays it cropped around the SmartCropper focus point.
private struct CollageCellView: View {
    let url: URL
    /// Normalized focus point in Vision coordinates (origin at bottom-left, 0…1).
    let focusPoint: CGPoint?
    let thumbnailSize: CGSize
    var refreshID: Int = 0
    @State private var image: NSImage?

    /// Combined identity so the task re-fires on URL change or cache clear.
    private var taskID: String {
        "\(url.absoluteString)-\(refreshID)"
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Rectangle().fill(.quaternary.opacity(0.3))

                if let image {
                    let imgSize = image.size
                    let scale = max(
                        geo.size.width / imgSize.width,
                        geo.size.height / imgSize.height
                    )
                    let scaledW = imgSize.width * scale
                    let scaledH = imgSize.height * scale

                    // Convert Vision focus point (bottom-left origin) to SwiftUI (top-left)
                    let fpX = focusPoint?.x ?? 0.5
                    let fpY = 1.0 - (focusPoint?.y ?? 0.5)

                    // Offset so the focus point sits at the center of the cell
                    let rawOffsetX = (0.5 - fpX) * scaledW
                    let rawOffsetY = (0.5 - fpY) * scaledH

                    // Clamp so we don't expose empty space
                    let maxOffsetX = (scaledW - geo.size.width) / 2
                    let maxOffsetY = (scaledH - geo.size.height) / 2
                    let clampedX = max(-maxOffsetX, min(maxOffsetX, rawOffsetX))
                    let clampedY = max(-maxOffsetY, min(maxOffsetY, rawOffsetY))

                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: scaledW, height: scaledH)
                        .offset(x: clampedX, y: clampedY)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
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
        samples: [
            SamplePhoto(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/.thumbnails/Dome Light.heic")),
            SamplePhoto(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/.thumbnails/Dome Dark.heic")),
            SamplePhoto(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/.thumbnails/Tree Dark.heic")),
            SamplePhoto(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/.thumbnails/Big Sur Coastline.heic")),
        ],
        gridSize: 2
    )
    .frame(width: 200, height: 200)
    .clipShape(RoundedRectangle(cornerRadius: 12))
}

#Preview("Collage 3x3") {
    CollageView(
        samples: [
            SamplePhoto(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/.thumbnails/Dome Light.heic")),
            SamplePhoto(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/.thumbnails/Dome Dark.heic")),
            SamplePhoto(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/.thumbnails/Tree Dark.heic")),
            SamplePhoto(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/.thumbnails/Big Sur Coastline.heic")),
        ],
        gridSize: 3
    )
    .frame(width: 300, height: 300)
    .clipShape(RoundedRectangle(cornerRadius: 12))
}

#Preview("Collage - Empty") {
    CollageView(samples: [], gridSize: 2)
        .frame(width: 200, height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 12))
}
