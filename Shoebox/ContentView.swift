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
import Combine

struct ContentView: View {
    @EnvironmentObject var collectionManager: CollectionManager
    @EnvironmentObject var favoritesManager: FavoritesManager
    @StateObject private var photoLoader = PhotoLoader()
    @State private var selectedPhoto: PhotoItem?
    @State private var showingSlideshow = false
    @State private var showDetailInfo = false
    @State private var detailPhotoID: PhotoItem.ID?
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var searchText = ""
    @State private var favoritesExportObservation: AnyCancellable?
    @State private var favoritesExportLoader: PhotoLoader?
    @State private var folderWatcher: FolderWatcher?
    @State private var indexProgress = IndexProgress(completed: 0, total: 0)
    @State private var indexMatchIDs: Set<String> = []
    @State private var indexSearchTask: Task<Void, Never>?
    @State private var indexingTask: Task<Void, Never>?
    @State private var similaritySourceID: String?
    @State private var similarityResults: [String] = []
    @State private var showUnlockSheet = false
    @State private var pendingRemoveLock = false

    var filteredPhotos: [PhotoItem] {
        if similaritySourceID != nil {
            let lookup = Dictionary(uniqueKeysWithValues: photoLoader.photos.map { ($0.id, $0) })
            return similarityResults.compactMap { lookup[$0] }
        }
        if searchText.isEmpty {
            return photoLoader.photos
        }
        return photoLoader.photos.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) || indexMatchIDs.contains($0.id)
        }
    }

    private var detailCurrentPhoto: PhotoItem? {
        guard let id = detailPhotoID else { return selectedPhoto }
        return filteredPhotos.first { $0.id == id }
    }

    var body: some View {
        ZStack {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView()
            } detail: {
                if collectionManager.isSelectedCollectionPasswordProtected && collectionManager.isLocked {
                    LockedCollectionView()
                } else if collectionManager.isFavoritesSelected || collectionManager.selectedCollection != nil {
                    PhotoGridView(
                        photos: filteredPhotos,
                        isLoading: photoLoader.isLoading,
                        selectedPhoto: $selectedPhoto,
                        indexProgress: indexProgress,
                        similaritySourceID: $similaritySourceID,
                        onFindSimilar: { photoID in findSimilar(to: photoID) }
                    )
                    .searchable(text: $searchText, prompt: "Search by name or content")
                } else {
                    EmptyStateView()
                }
            }
            .navigationTitle(collectionManager.isFavoritesSelected ? "Favorites" : collectionManager.selectedCollection?.name ?? "Shoebox")
            .toolbar {
                ToolbarItem {
                    lockToggleButton
                }

                ToolbarItem {
                    removeLockButton
                }

                if selectedPhoto == nil, !showingSlideshow, !(collectionManager.isSelectedCollectionPasswordProtected && collectionManager.isLocked), !filteredPhotos.isEmpty {
                    ToolbarItem {
                        Button {
                            detailPhotoID = filteredPhotos.first?.id
                            showingSlideshow = true
                        } label: {
                            Label("Slideshow", systemImage: "play.fill")
                        }
                    }
                }

                if selectedPhoto != nil, !showingSlideshow, let photo = detailCurrentPhoto {
                    ToolbarItemGroup {
                        FavoriteButton(photo: photo)

                        ShareButton(url: photo.url)
                            .frame(width: 28, height: 22)
                            .help("Share")

                        Button {
                            showDetailInfo.toggle()
                        } label: {
                            Image(systemName: showDetailInfo ? "info.circle.fill" : "info.circle")
                        }
                        .help("Info")
                    }
                }
            }
            .frame(minWidth: 800, minHeight: 500)
            .toolbar(showingSlideshow ? .hidden : .automatic, for: .windowToolbar)

            if selectedPhoto != nil || showingSlideshow {
                PhotoDetailView(
                    photos: filteredPhotos,
                    isPresented: Binding(
                        get: { selectedPhoto != nil || showingSlideshow },
                        set: { if !$0 { selectedPhoto = nil; showingSlideshow = false } }
                    ),
                    showInfo: $showDetailInfo,
                    scrolledPhotoID: $detailPhotoID,
                    slideshowMode: showingSlideshow,
                    onFindSimilar: { photoID in
                        selectedPhoto = nil
                        showingSlideshow = false
                        findSimilar(to: photoID)
                    }
                )
                .transition(.opacity)
            }
        }
        .onChange(of: selectedPhoto) { _, newValue in
            if let photo = newValue {
                detailPhotoID = photo.id
                showDetailInfo = false
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedPhoto != nil || showingSlideshow)
        .onAppear {
            folderWatcher = FolderWatcher { [self] in
                loadSelectedCollection()
            }
            loadSelectedCollection()
            Task {
                await ImageIndexer.shared.setProgressHandler { progress in
                    Task { @MainActor in
                        indexProgress = progress
                    }
                }
            }
        }
        .onChange(of: collectionManager.selectedCollectionID) { _, _ in
            similaritySourceID = nil
            similarityResults = []
            Task { @MainActor in
                loadSelectedCollection()
            }
        }
        .onChange(of: photoLoader.photos) { _, photos in
            Task { @MainActor in
                if collectionManager.isFavoritesSelected {
                    collectionManager.exportFavoritesForWidget(photos: photos)
                } else if let id = collectionManager.selectedCollectionID {
                    collectionManager.updatePhotoCount(for: id, count: photos.count)
                    collectionManager.exportForWidget(photos: photos)
                }
            }
            startIndexing(photos: photos)
        }
        .onChange(of: searchText) { _, query in
            if !query.isEmpty {
                similaritySourceID = nil
                similarityResults = []
            }
            updateIndexSearch(query: query)
        }
        .onChange(of: collectionManager.selectedCollection?.recurseSubdirectories) { _, _ in
            Task { @MainActor in
                if !collectionManager.isFavoritesSelected {
                    loadSelectedCollection()
                }
            }
        }
        .onChange(of: favoritesManager.favoriteIDs) { _, _ in
            Task { @MainActor in
                if collectionManager.isFavoritesSelected {
                    loadFavorites()
                } else {
                    exportFavoritesInBackground()
                }
            }
        }
        .onChange(of: collectionManager.isUnlocked) { _, unlocked in
            if unlocked && pendingRemoveLock {
                pendingRemoveLock = false
                collectionManager.removeLockFromSelectedCollection()
            }
            if !unlocked && collectionManager.isSelectedCollectionPasswordProtected {
                selectedPhoto = nil
                showingSlideshow = false
            }
            loadSelectedCollection()
        }
        .sheet(isPresented: $showUnlockSheet) {
            UnlockSheet()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFolder)) { _ in
            openFolder()
        }
    }

    // MARK: - Lock Toolbar Buttons

    @ViewBuilder
    private var lockToggleButton: some View {
        if collectionManager.isLocked {
            Button {
                triggerUnlock()
            } label: {
                Label("Unlock", systemImage: "lock.fill")
            }
            .help("Unlock All Collections")
        } else {
            Button {
                if !collectionManager.isSelectedCollectionPasswordProtected {
                    collectionManager.addLockToSelectedCollection()
                }
                collectionManager.lock()
            } label: {
                Label("Lock", systemImage: "lock.open")
            }
            .help("Lock All Collections")
        }
    }

    @ViewBuilder
    private var removeLockButton: some View {
        if collectionManager.isSelectedCollectionPasswordProtected {
            Button {
                handleRemoveLock()
            } label: {
                Label("Remove Lock", systemImage: "lock.slash")
            }
            .help("Remove Lock from This Collection")
        }
    }

    private func triggerUnlock() {
        switch collectionManager.lockMethod {
        case .loginPassword:
            Task { await collectionManager.authenticateWithLoginPassword() }
        case .customPassword:
            showUnlockSheet = true
        }
    }

    private func handleRemoveLock() {
        if collectionManager.isUnlocked {
            collectionManager.removeLockFromSelectedCollection()
        } else {
            pendingRemoveLock = true
            triggerUnlock()
        }
    }

    private func loadSelectedCollection() {
        guard let id = collectionManager.selectedCollectionID else {
            folderWatcher?.stop()
            photoLoader.clear()
            return
        }

        if id == CollectionManager.favoritesCollectionID {
            folderWatcher?.stop()
            loadFavorites()
            return
        }

        guard let collection = collectionManager.collections.first(where: { $0.id == id }) else {
            folderWatcher?.stop()
            photoLoader.clear()
            return
        }

        if collection.isPasswordProtected && collectionManager.isLocked {
            folderWatcher?.stop()
            photoLoader.clear()
            return
        }

        guard let url = collectionManager.startAccessing(collection: collection) else {
            folderWatcher?.stop()
            photoLoader.clear()
            return
        }
        folderWatcher?.watch(url: url)
        photoLoader.loadPhotos(from: url, recursive: collection.recurseSubdirectories)
    }

    private func loadFavorites() {
        let sources = collectionManager.isLocked
            ? collectionManager.startAccessingUnprotected()
            : collectionManager.startAccessingAll()
        photoLoader.loadFavorites(from: sources, matching: favoritesManager.favoriteIDs)
    }

    /// Re-export favorites thumbnails for the widget without switching views.
    private func exportFavoritesInBackground() {
        let favoriteIDs = favoritesManager.favoriteIDs
        guard !favoriteIDs.isEmpty else {
            // Clean up the directory if no favorites remain
            if let dir = ShoeboxKit.widgetThumbnailsURL(forCollectionID: CollectionManager.favoritesCollectionID) {
                try? FileManager.default.removeItem(at: dir)
            }
            return
        }
        let backgroundLoader = PhotoLoader()
        let sources = collectionManager.startAccessingAll()
        backgroundLoader.loadFavorites(from: sources, matching: favoriteIDs)
        // Observe when loading completes to trigger export
        favoritesExportObservation?.cancel()
        favoritesExportLoader = backgroundLoader
        favoritesExportObservation = backgroundLoader.$photos
            .dropFirst()
            .first(where: { _ in !backgroundLoader.isLoading })
            .sink { photos in
                collectionManager.exportFavoritesForWidget(photos: photos)
            }
    }

    private func findSimilar(to photoID: String) {
        searchText = ""
        similaritySourceID = photoID
        Task {
            let ids = Set(photoLoader.photos.map(\.id))
            let results = await ImageIndexer.shared.findSimilar(to: photoID, in: ids)
            await MainActor.run {
                similarityResults = results
            }
        }
    }

    private func startIndexing(photos: [PhotoItem]) {
        indexingTask?.cancel()
        let collectionID = collectionManager.selectedCollectionID ?? UUID()
        indexingTask = Task {
            await ImageIndexer.shared.index(photos: photos, collectionID: collectionID)
        }
    }

    private func updateIndexSearch(query: String) {
        indexSearchTask?.cancel()
        guard !query.isEmpty else {
            indexMatchIDs = []
            return
        }
        indexSearchTask = Task {
            let ids = Set(photoLoader.photos.map(\.id))
            let matches = await ImageIndexer.shared.search(query: query, in: ids)
            if !Task.isCancelled {
                await MainActor.run {
                    indexMatchIDs = matches
                }
            }
        }
    }

    private func openFolder() {
        if let url = presentFolderPanel() {
            collectionManager.addCollection(from: url)
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(CollectionManager())
        .environmentObject(FavoritesManager())
        .frame(width: 1000, height: 650)
}
