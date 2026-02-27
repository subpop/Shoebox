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
import Vision

struct IndexEntry: Codable {
    var tags: [String]
    var text: [String]
    var fileModified: Date
    var featurePrintData: Data?
}

struct IndexProgress: Sendable {
    var completed: Int
    var total: Int

    var isActive: Bool { total > 0 && completed < total }
}

actor ImageIndexer {
    static let shared = ImageIndexer()

    private var entries: [String: IndexEntry] = [:]
    private var currentCollectionID: UUID?
    private var indexingTask: Task<Void, Never>?
    private var onProgress: (@Sendable (IndexProgress) -> Void)?

    private static let classificationConfidenceThreshold: Float = 0.4
    private static let thumbnailSize: CGFloat = 800

    private var diskCacheURL: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier ?? "Shoebox"
        return caches.appendingPathComponent(bundleID).appendingPathComponent("ImageIndex")
    }

    // MARK: - Public API

    func setProgressHandler(_ handler: (@Sendable (IndexProgress) -> Void)?) {
        onProgress = handler
    }

    func index(photos: [PhotoItem], collectionID: UUID) {
        indexingTask?.cancel()
        currentCollectionID = collectionID
        loadFromDisk(collectionID: collectionID)
        pruneStaleEntries(currentPhotoIDs: Set(photos.map(\.id)))

        let photosToIndex = photos.filter { photo in
            guard let existing = entries[photo.id] else { return true }
            return existing.fileModified != photo.dateModified
        }

        guard !photosToIndex.isEmpty else {
            onProgress?(IndexProgress(completed: 0, total: 0))
            return
        }

        let total = photosToIndex.count
        onProgress?(IndexProgress(completed: 0, total: total))

        indexingTask = Task(priority: .utility) { [weak self] in
            for (i, photo) in photosToIndex.enumerated() {
                if Task.isCancelled { return }
                guard let self else { return }
                let entry = Self.analyzeImage(at: photo.url, modified: photo.dateModified)
                await self.storeEntry(entry, forID: photo.id)
                await self.emitProgress(completed: i + 1, total: total)
            }
            guard !Task.isCancelled, let self else { return }
            await self.saveToDisk(collectionID: collectionID)
        }
    }

    func search(query: String, in photoIDs: Set<String>) -> Set<String> {
        let lowered = query.lowercased()
        var matches = Set<String>()
        for id in photoIDs {
            guard let entry = entries[id] else { continue }
            let tagMatch = entry.tags.contains { $0.localizedCaseInsensitiveContains(lowered) }
            let textMatch = entry.text.contains { $0.localizedCaseInsensitiveContains(lowered) }
            if tagMatch || textMatch {
                matches.insert(id)
            }
        }
        return matches
    }

    /// Returns photo IDs sorted by visual similarity to the source photo (most similar first).
    /// Only includes photos within `maxDistance` of the source. Feature-print distances are
    /// unbounded floats where 0 is identical; values under ~10 are visually close.
    func findSimilar(to photoID: String, in photoIDs: Set<String>, maxDistance: Float = 0.5) -> [String] {
        guard let sourceEntry = entries[photoID],
              let sourceData = sourceEntry.featurePrintData,
              let sourcePrint = Self.deserializeFeaturePrint(sourceData)
        else { return [] }

        var scored: [(id: String, distance: Float)] = []
        for id in photoIDs where id != photoID {
            guard let entry = entries[id],
                  let data = entry.featurePrintData,
                  let print = Self.deserializeFeaturePrint(data)
            else { continue }
            var distance: Float = 0
            try? sourcePrint.computeDistance(&distance, to: print)
            if distance <= maxDistance {
                scored.append((id, distance))
            }
        }

        scored.sort { $0.distance < $1.distance }
        return scored.map(\.id)
    }

    func cancelIndexing() {
        indexingTask?.cancel()
        indexingTask = nil
        onProgress?(IndexProgress(completed: 0, total: 0))
    }

    // MARK: - Internal Helpers

    private func storeEntry(_ entry: IndexEntry, forID id: String) {
        entries[id] = entry
    }

    private func emitProgress(completed: Int, total: Int) {
        onProgress?(IndexProgress(completed: completed, total: total))
    }

    private func pruneStaleEntries(currentPhotoIDs: Set<String>) {
        for key in entries.keys where !currentPhotoIDs.contains(key) {
            entries.removeValue(forKey: key)
        }
    }

    // MARK: - Vision Analysis

    private static func analyzeImage(at url: URL, modified: Date) -> IndexEntry {
        guard let cgImage = ThumbnailGenerator.createThumbnail(from: url, maxPixelSize: thumbnailSize) else {
            return IndexEntry(tags: [], text: [], fileModified: modified)
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let classifyRequest = VNClassifyImageRequest()
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        let featurePrintRequest = VNGenerateImageFeaturePrintRequest()

        try? handler.perform([classifyRequest, textRequest, featurePrintRequest])

        let tags = (classifyRequest.results ?? [])
            .filter { $0.confidence >= classificationConfidenceThreshold }
            .map { $0.identifier }

        let recognizedText = (textRequest.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }

        let featurePrintData: Data? = featurePrintRequest.results?.first.flatMap {
            serializeFeaturePrint($0)
        }

        return IndexEntry(tags: tags, text: recognizedText, fileModified: modified, featurePrintData: featurePrintData)
    }

    // MARK: - Feature Print Serialization

    private static func serializeFeaturePrint(_ observation: VNFeaturePrintObservation) -> Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: observation, requiringSecureCoding: true)
    }

    private static func deserializeFeaturePrint(_ data: Data) -> VNFeaturePrintObservation? {
        try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: data)
    }

    // MARK: - Disk Persistence

    private func indexFileURL(collectionID: UUID) -> URL {
        diskCacheURL.appendingPathComponent(collectionID.uuidString + ".json")
    }

    private func loadFromDisk(collectionID: UUID) {
        let fileURL = indexFileURL(collectionID: collectionID)
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: IndexEntry].self, from: data)
        else {
            entries = [:]
            return
        }
        entries = decoded
    }

    private func saveToDisk(collectionID: UUID) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: diskCacheURL.path) {
            try? fm.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        }
        let fileURL = indexFileURL(collectionID: collectionID)
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
