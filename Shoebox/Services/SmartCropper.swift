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

import Vision
import AppKit

enum SmartCropper {
    /// Analyzes a CGImage using Vision.framework and returns a normalized focus point
    /// in Vision coordinates (origin at bottom-left, values 0…1).
    ///
    /// Strategy:
    /// 1. Detect faces — if found, return the average center of all face bounding boxes.
    /// 2. Fall back to attention-based saliency — return the center of the most salient region.
    /// 3. Default to (0.5, 0.5) — equivalent to a center crop.
    static func focusPoint(for cgImage: CGImage) -> CGPoint {
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        // Try face detection first
        let faceRequest = VNDetectFaceRectanglesRequest()
        try? handler.perform([faceRequest])

        if let faces = faceRequest.results, !faces.isEmpty {
            let centers = faces.map { CGPoint(
                x: $0.boundingBox.midX,
                y: $0.boundingBox.midY
            )}
            let avgX = centers.map(\.x).reduce(0, +) / CGFloat(centers.count)
            let avgY = centers.map(\.y).reduce(0, +) / CGFloat(centers.count)
            return CGPoint(x: avgX, y: avgY)
        }

        // Fallback: attention-based saliency
        let saliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest()
        try? handler.perform([saliencyRequest])

        if let result = saliencyRequest.results?.first,
           let salientObject = result.salientObjects?.first {
            return CGPoint(
                x: salientObject.boundingBox.midX,
                y: salientObject.boundingBox.midY
            )
        }

        // Default center
        return CGPoint(x: 0.5, y: 0.5)
    }
}
