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

import CryptoKit
import Foundation
import LocalAuthentication
import SwiftUI
import WidgetKit

enum LockMethod: String {
    case loginPassword
    case customPassword
}

@MainActor
class CollectionManager: ObservableObject {
    static let favoritesCollectionID = ShoeboxKit.favoritesCollectionID

    @Published var collections: [PhotoCollection] = []
    @Published var selectedCollectionID: UUID? {
        didSet { saveSelectedCollectionID() }
    }
    @Published private(set) var isUnlocked = false
    @Published private(set) var lockMethod: LockMethod = .loginPassword
    private let defaults: UserDefaults
    private var accessedURL: URL?
    private var accessedURLs: [URL] = []

    var selectedCollection: PhotoCollection? {
        collections.first { $0.id == selectedCollectionID }
    }

    var isFavoritesSelected: Bool {
        selectedCollectionID == Self.favoritesCollectionID
    }

    // MARK: - Lock

    var hasCustomPassword: Bool {
        defaults.string(forKey: ShoeboxKit.lockPasswordHashKey) != nil
    }

    var hasAnyLockedCollections: Bool {
        collections.contains { $0.isPasswordProtected }
    }

    var isLocked: Bool {
        hasAnyLockedCollections && !isUnlocked
    }

    var isSelectedCollectionPasswordProtected: Bool {
        return selectedCollection?.isPasswordProtected ?? false
    }

    func setLockMethod(_ method: LockMethod) {
        lockMethod = method
        defaults.set(method.rawValue, forKey: ShoeboxKit.lockMethodKey)
        if method == .loginPassword {
            clearCustomPassword()
        }
    }

    func clearCustomPassword() {
        defaults.removeObject(forKey: ShoeboxKit.lockPasswordHashKey)
    }

    func setCustomPassword(_ password: String) {
        defaults.set(Self.hashPassword(password), forKey: ShoeboxKit.lockPasswordHashKey)
        isUnlocked = true
    }

    func unlock(password: String) -> Bool {
        guard verifyPassword(password) else { return false }
        isUnlocked = true
        return true
    }

    func lock() {
        guard hasAnyLockedCollections else { return }
        isUnlocked = false
    }

    func authenticateWithLoginPassword() async -> Bool {
        let context = LAContext()
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock your collections"
            )
            if success { isUnlocked = true }
            return success
        } catch {
            return false
        }
    }

    func addLockToSelectedCollection() {
        guard let id = selectedCollectionID,
              let idx = collections.firstIndex(where: { $0.id == id }) else { return }
        collections[idx].isPasswordProtected = true
        saveCollections()
    }

    func removeLockFromSelectedCollection() {
        guard let id = selectedCollectionID,
              let idx = collections.firstIndex(where: { $0.id == id }) else { return }
        collections[idx].isPasswordProtected = false
        saveCollections()
    }

    private func verifyPassword(_ password: String) -> Bool {
        guard let stored = defaults.string(forKey: ShoeboxKit.lockPasswordHashKey) else { return false }
        return Self.hashPassword(password) == stored
    }

    static func hashPassword(_ password: String) -> String {
        let data = Data(password.utf8)
        return SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }

    init() {
        self.defaults = ShoeboxKit.sharedDefaults

        if let raw = defaults.string(forKey: ShoeboxKit.lockMethodKey),
           let method = LockMethod(rawValue: raw) {
            lockMethod = method
        } else if defaults.string(forKey: ShoeboxKit.lockPasswordHashKey) != nil {
            lockMethod = .customPassword
        }
        loadCollections()
    }

    deinit {
        accessedURL?.stopAccessingSecurityScopedResource()
        for url in accessedURLs {
            url.stopAccessingSecurityScopedResource()
        }
    }

    // MARK: - Collection Management

    func addCollection(from url: URL) {
        if let existing = collections.first(where: { $0.path == url.path }) {
            selectedCollectionID = existing.id
            return
        }

        let bookmarkData = try? url.bookmarkData(
            options: [.securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        let count = countPhotos(in: url)

        let collection = PhotoCollection(
            name: url.lastPathComponent,
            path: url.path,
            bookmarkData: bookmarkData,
            photoCount: count
        )

        collections.append(collection)
        selectedCollectionID = collection.id
        saveCollections()
    }

    func moveCollection(fromOffsets source: IndexSet, toOffset destination: Int) {
        collections.move(fromOffsets: source, toOffset: destination)
        saveCollections()
    }

    func removeCollection(_ collection: PhotoCollection) {
        collections.removeAll { $0.id == collection.id }
        if selectedCollectionID == collection.id {
            selectedCollectionID = collections.first?.id
        }
        saveCollections()

        // Clean up widget thumbnails for the removed collection
        if let thumbnailDir = ShoeboxKit.widgetThumbnailsURL(forCollectionID: collection.id) {
            try? FileManager.default.removeItem(at: thumbnailDir)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func updatePhotoCount(for collectionID: UUID, count: Int) {
        if let idx = collections.firstIndex(where: { $0.id == collectionID }) {
            collections[idx].photoCount = count
            saveCollections()
        }
    }

    func updateCollection(_ collection: PhotoCollection) {
        if let idx = collections.firstIndex(where: { $0.id == collection.id }) {
            collections[idx] = collection
            saveCollections()
        }
    }

    // MARK: - URL Resolution & Security Scope

    func startAccessing(collection: PhotoCollection) -> URL? {
        accessedURL?.stopAccessingSecurityScopedResource()
        accessedURL = nil

        guard let url = resolveURL(for: collection) else { return nil }

        let accessing = url.startAccessingSecurityScopedResource()
        if accessing {
            accessedURL = url
        }

        return url
    }

    /// Start security-scoped access to all collections at once (used for Favorites).
    /// Returns each collection's resolved URL paired with its `recurseSubdirectories` flag.
    func startAccessingAll() -> [(url: URL, recursive: Bool)] {
        startAccessing(collections: collections)
    }

    /// Like `startAccessingAll()` but skips password-protected collections.
    func startAccessingUnprotected() -> [(url: URL, recursive: Bool)] {
        startAccessing(collections: collections.filter { !$0.isPasswordProtected })
    }

    private func startAccessing(collections subset: [PhotoCollection]) -> [(url: URL, recursive: Bool)] {
        accessedURL?.stopAccessingSecurityScopedResource()
        accessedURL = nil
        stopAccessingAll()

        var results: [(url: URL, recursive: Bool)] = []
        for collection in subset {
            guard let url = resolveURL(for: collection) else { continue }
            if url.startAccessingSecurityScopedResource() {
                accessedURLs.append(url)
            }
            results.append((url, collection.recurseSubdirectories))
        }
        return results
    }

    private func stopAccessingAll() {
        for url in accessedURLs {
            url.stopAccessingSecurityScopedResource()
        }
        accessedURLs.removeAll()
    }

    func resolveURL(for collection: PhotoCollection) -> URL? {
        if let bookmarkData = collection.bookmarkData {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                if isStale {
                    refreshBookmark(for: collection, url: url)
                }
                return url
            }
        }
        let url = URL(fileURLWithPath: collection.path)
        if FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        return nil
    }

    // MARK: - Persistence

    func saveCollections() {
        if let data = try? JSONEncoder().encode(collections) {
            defaults.set(data, forKey: ShoeboxKit.collectionsKey)
        }
    }

    private func loadCollections() {
        collections = ShoeboxKit.loadCollections()

        if let savedID = defaults.string(forKey: ShoeboxKit.selectedCollectionIDKey),
           let uuid = UUID(uuidString: savedID),
           uuid == Self.favoritesCollectionID || collections.contains(where: { $0.id == uuid }) {
            selectedCollectionID = uuid
        } else {
            selectedCollectionID = collections.first?.id
        }
    }

    private func saveSelectedCollectionID() {
        defaults.set(selectedCollectionID?.uuidString, forKey: ShoeboxKit.selectedCollectionIDKey)
    }

    // MARK: - Widget Export

    private var exportTask: Task<Void, Never>?

    private static let widgetExportLimit = 48

    func exportFavoritesForWidget(photos: [PhotoItem]) {
        guard let collectionDir = ShoeboxKit.widgetThumbnailsURL(forCollectionID: Self.favoritesCollectionID) else { return }
        runWidgetExport(photos: photos, to: collectionDir)
    }

    func exportForWidget(photos: [PhotoItem]) {
        guard let collection = selectedCollection else { return }
        guard let collectionDir = ShoeboxKit.widgetThumbnailsURL(forCollectionID: collection.id) else { return }
        runWidgetExport(photos: photos, to: collectionDir)
    }

    private func runWidgetExport(photos: [PhotoItem], to collectionDir: URL) {
        let selected = Array(photos.shuffled().prefix(Self.widgetExportLimit))
        exportTask?.cancel()
        exportTask = Task.detached(priority: .utility) {
            let fm = FileManager.default
            if fm.fileExists(atPath: collectionDir.path) {
                try? fm.removeItem(at: collectionDir)
            }
            try? fm.createDirectory(at: collectionDir, withIntermediateDirectories: true)

            var focusPoints: [String: [String: CGFloat]] = [:]

            for (i, photo) in selected.enumerated() {
                if Task.isCancelled { return }
                if let result = Self.exportThumbnail(from: photo.url, to: collectionDir, index: i) {
                    focusPoints[result.filename] = ["x": result.focusPoint.x, "y": result.focusPoint.y]
                }
            }

            // Write focus-point manifest
            let manifestURL = collectionDir.appendingPathComponent(ShoeboxKit.focusPointsManifestName)
            if let data = try? JSONSerialization.data(withJSONObject: focusPoints, options: [.sortedKeys]) {
                try? data.write(to: manifestURL)
            }

            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    nonisolated private static func exportThumbnail(from url: URL, to directory: URL, index: Int) -> (filename: String, focusPoint: CGPoint)? {
        guard let cgImage = ThumbnailGenerator.createThumbnail(from: url, maxPixelSize: ShoeboxKit.processingThumbnailSize) else { return nil }

        let focusPoint = SmartCropper.focusPoint(for: cgImage)

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else { return nil }

        let fileName = String(format: "%03d.jpg", index)
        let fileURL = directory.appendingPathComponent(fileName)
        guard (try? jpegData.write(to: fileURL)) != nil else { return nil }

        return (fileName, focusPoint)
    }

    private func refreshBookmark(for collection: PhotoCollection, url: URL) {
        if let newData = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            if let idx = collections.firstIndex(where: { $0.id == collection.id }) {
                collections[idx].bookmarkData = newData
                saveCollections()
            }
        }
    }

    private func countPhotos(in url: URL, recursive: Bool = true) -> Int {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        return ShoeboxKit.imageURLs(in: url, recursive: recursive).count
    }
}

