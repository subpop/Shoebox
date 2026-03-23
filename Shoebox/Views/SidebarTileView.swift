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

/// A square tile displaying a photo collage background with a collection's
/// name and photo count overlaid. Used in the sidebar grid display mode.
struct SidebarTileView: View {
    let title: String
    let count: Int
    let samples: [SamplePhoto]
    var collageGridSize: Int = 2
    var refreshID: Int = 0
    var isPasswordProtected: Bool = false
    var isLocked: Bool = false
    var isSelected: Bool = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Collage background
            CollageView(samples: samples, gridSize: collageGridSize, refreshID: refreshID)

            // Blur overlay when locked
            if isPasswordProtected && isLocked {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Image(systemName: "lock.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
            }

            // Bottom gradient scrim for text readability
            if !samples.isEmpty && !(isPasswordProtected && isLocked) {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }

            // Text overlay
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(ShoeboxKit.photoCountLabel(count))
                    .font(.caption2)
            }
            .foregroundColor(samples.isEmpty ? Color.primary : Color.white)
            .shadow(color: samples.isEmpty ? .clear : .black.opacity(0.5), radius: 2, x: 0, y: 1)
            .padding(8)

            // Lock icon (top-right)
            if isPasswordProtected && !isLocked {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "lock.open.fill")
                            .font(.caption2)
                            .foregroundColor(samples.isEmpty ? Color.secondary : Color.white.opacity(0.8))
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                            .padding(6)
                    }
                    Spacer()
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.clear,
                    lineWidth: 2.5
                )
        )
    }
}

// MARK: - Previews

#Preview("Tile - With Photos") {
    SidebarTileView(
        title: "Vacation Photos",
        count: 42,
        samples: [
            SamplePhoto(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/.thumbnails/Dome Light.heic")),
            SamplePhoto(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/.thumbnails/Dome Dark.heic")),
            SamplePhoto(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/.thumbnails/Tree Dark.heic")),
            SamplePhoto(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/.thumbnails/Big Sur Coastline.heic")),
        ]
    )
    .frame(width: 140, height: 140)
}

#Preview("Tile - Selected") {
    SidebarTileView(
        title: "Vacation Photos",
        count: 42,
        samples: [
            SamplePhoto(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/.thumbnails/Dome Light.heic")),
            SamplePhoto(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/.thumbnails/Dome Dark.heic")),
            SamplePhoto(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/.thumbnails/Tree Dark.heic")),
            SamplePhoto(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/.thumbnails/Big Sur Coastline.heic")),
        ],
        isSelected: true
    )
    .frame(width: 140, height: 140)
}

#Preview("Tile - Locked") {
    SidebarTileView(
        title: "Private",
        count: 12,
        samples: [
            SamplePhoto(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/.thumbnails/Dome Light.heic")),
        ],
        isPasswordProtected: true,
        isLocked: true
    )
    .frame(width: 140, height: 140)
}

#Preview("Tile - Empty") {
    SidebarTileView(
        title: "Empty Folder",
        count: 0,
        samples: []
    )
    .frame(width: 140, height: 140)
}
