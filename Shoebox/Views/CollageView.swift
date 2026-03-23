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

/// A collage of photo thumbnails composited into a single cached image.
/// Uses SmartCropper focus points to align the most interesting part of
/// each photo within its grid cell during compositing.
struct CollageView: View {
    let samples: [SamplePhoto]
    var gridSize: Int = 2
    var thumbnailSize: CGSize = CGSize(width: 150, height: 150)
    /// Changing this value forces the composite to regenerate.
    var refreshID: Int = 0

    /// Task identity that triggers re-compositing when inputs change.
    private var taskID: String {
        let urls = samples.prefix(gridSize * gridSize).map(\.url.absoluteString).joined(separator: ",")
        let fps = samples.prefix(gridSize * gridSize).map { s in
            s.focusPoint.map { "\($0.x),\($0.y)" } ?? "nil"
        }.joined(separator: ",")
        return "\(urls)|\(fps)|\(gridSize)|\(refreshID)"
    }

    @State private var compositeImage: NSImage?

    var body: some View {
        if samples.isEmpty {
            Rectangle().fill(.quaternary.opacity(0.5))
        } else {
            GeometryReader { geometry in
                ZStack {
                    Rectangle().fill(.quaternary.opacity(0.3))

                    if let compositeImage {
                        Image(nsImage: compositeImage)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
                .task(id: taskID) {
                    compositeImage = nil
                    compositeImage = await ThumbnailCache.shared.compositeCollage(
                        samples: Array(samples.prefix(gridSize * gridSize)),
                        gridSize: gridSize,
                        totalSize: geometry.size
                    )
                }
            }
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
