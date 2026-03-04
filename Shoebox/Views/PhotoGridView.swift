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

private let gridItemSpacing: CGFloat = 12

struct PhotoGridView: View {
    let photos: [PhotoItem]
    let isLoading: Bool
    @Binding var selectedPhoto: PhotoItem?
    var indexProgress = IndexProgress(completed: 0, total: 0)
    @Binding var similaritySourceID: String?
    @Binding var showingSlideshow: Bool
    @Binding var detailPhotoID: PhotoItem.ID?
    @Binding var showUnlockSheet: Bool
    @Binding var pendingRemoveLock: Bool
    var onFindSimilar: ((String) -> Void)?
    @EnvironmentObject var collectionManager: CollectionManager
    @EnvironmentObject var favoritesManager: FavoritesManager

    @State private var gridColumns = 5
    @State private var hoveredPhoto: PhotoItem?

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: gridItemSpacing),
            count: gridColumns
        )
    }

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if photos.isEmpty && similaritySourceID != nil {
                noSimilarPhotosView
            } else if photos.isEmpty {
                noPhotosView
            } else {
                gridContent
            }
        }
        .safeAreaBar(edge: .bottom) {
            toolbar
        }
        .navigationTitle(selectedPhoto == nil ? currentTitle : "")
        .toolbar { windowToolbarContent }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text(ShoeboxKit.photoCountLabel(photos.count))
                .font(.callout)
                .foregroundStyle(.secondary)

            if indexProgress.isActive {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Indexing \(indexProgress.completed)/\(indexProgress.total)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
                .transition(.opacity)
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "square.grid.3x3")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Slider(
                    value: Binding(
                        get: { Double(14 - gridColumns) },
                        set: { gridColumns = max(2, min(12, 14 - Int($0))) }
                    ),
                    in: 2...12,
                    step: 1
                )
                .frame(width: 100)
                Image(systemName: "square.grid.2x2")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Window Toolbar Content

    @ToolbarContentBuilder
    var windowToolbarContent: some ToolbarContent {
        if selectedPhoto != nil {
            ToolbarItem(placement: .navigation) {
                toolbarTitleCapsule
            }
        }

        ToolbarItemGroup(placement: .primaryAction) {
            lockToggleButton
            removeLockButton

            if selectedPhoto == nil, !showingSlideshow, !(collectionManager.isSelectedCollectionPasswordProtected && collectionManager.isLocked), !photos.isEmpty {
                Button {
                    detailPhotoID = photos.first?.id
                    showingSlideshow = true
                } label: {
                    Label("Slideshow", systemImage: "play.fill")
                }
            }
        }
    }

    private var currentTitle: String {
        if selectedPhoto != nil || showingSlideshow,
           let id = detailPhotoID,
           let photo = photos.first(where: { $0.id == id }) {
            photo.name
        } else {
            collectionManager.isFavoritesSelected ? "Favorites" : collectionManager.selectedCollection?.name ?? "Shoebox"
        }
    }

    private var toolbarTitleCapsule: some View {
        Text(currentTitle)
            .font(.title3)
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
    }

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

    // MARK: - Grid

    private var gridContent: some View {
        ScrollView {
            if similaritySourceID != nil {
                similarityBanner
            }
            LazyVGrid(columns: columns, spacing: gridItemSpacing) {
                ForEach(photos) { photo in
                    ThumbnailView(photo: photo)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .aspectRatio(nil, contentMode: .fit)
                        .background(
                            ConcentricRectangle()
                                .fill(.quaternary.opacity(0.5))
                        )
                        .clipShape(ConcentricRectangle())
                        .overlay(alignment: .topTrailing) {
                            favoriteOverlay(for: photo)
                        }
                        .overlay(
                            ConcentricRectangle()
                                .stroke(
                                    hoveredPhoto == photo ? Color.accentColor : Color.clear,
                                    lineWidth: 3
                                )
                        )
                        .shadow(
                            color: .black.opacity(hoveredPhoto == photo ? 0.25 : 0.08),
                            radius: hoveredPhoto == photo ? 6 : 2
                        )
                        .scaleEffect(hoveredPhoto == photo ? 1.03 : 1.0)
                        .animation(.easeInOut(duration: 0.15), value: hoveredPhoto?.id)
                        .onHover { isHovered in
                            hoveredPhoto = isHovered ? photo : nil
                        }
                        .onTapGesture(count: 2) {
                            selectedPhoto = photo
                        }
                        .help(photo.name)
                        .containerShape(RoundedRectangle(cornerRadius: 10))
                        .contextMenu {
                            Button {
                                favoritesManager.toggleFavorite(photo)
                            } label: {
                                Label(
                                    favoritesManager.isFavorite(photo) ? "Unfavorite" : "Favorite",
                                    systemImage: favoritesManager.isFavorite(photo) ? "heart.slash" : "heart"
                                )
                            }
                            Button {
                                onFindSimilar?(photo.id)
                            } label: {
                                Label("Find Similar", systemImage: "sparkle.magnifyingglass")
                            }
                            Divider()
                            Button {
                                if let image = NSImage(contentsOf: photo.url) {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.writeObjects([image])
                                }
                            } label: {
                                Label("Copy Image", systemImage: "doc.on.doc")
                            }
                            Button {
                                if let screen = NSScreen.main {
                                    try? NSWorkspace.shared.setDesktopImageURL(photo.url, for: screen, options: [:])
                                }
                            } label: {
                                Label("Set as Desktop Wallpaper", systemImage: "desktopcomputer")
                            }
                            Divider()
                            Button {
                                NSWorkspace.shared.activateFileViewerSelecting([photo.url])
                            } label: {
                                Label("Show in Finder", systemImage: "folder")
                            }
                        }
                }
            }
            .padding(12)
        }
    }

    // MARK: - Similarity Banner

    private var similarityBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkle.magnifyingglass")
                .foregroundStyle(.secondary)
            Text("Showing similar photos")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                similaritySourceID = nil
            } label: {
                Text("Clear")
                    .font(.callout)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Favorite Overlay

    @ViewBuilder
    private func favoriteOverlay(for photo: PhotoItem) -> some View {
        let isFav = favoritesManager.isFavorite(photo)
        let isHovered = hoveredPhoto == photo

        if isFav || isHovered {
            FavoriteButton(photo: photo, inactiveColor: .white)
                .font(.callout)
                .fontWeight(.bold)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                .padding(6)
                .transition(.opacity)
                .buttonStyle(.plain)
        }
    }

    // MARK: - Empty States

    private var noSimilarPhotosView: some View {
        PlaceholderView(
            icon: "sparkle.magnifyingglass",
            title: "No similar photos found",
            subtitle: "Try again after indexing completes, or with a different photo."
        ) {
            Button("Clear") {
                similaritySourceID = nil
            }
            .buttonStyle(.borderless)
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("Loading photos...")
                .progressViewStyle(.circular)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var noPhotosView: some View {
        PlaceholderView(
            icon: "photo.on.rectangle.angled",
            title: "No photos found",
            subtitle: "This folder doesn't contain any supported image files."
        )
    }
}

// MARK: - Placeholder View

/// Reusable empty-state view with an icon, title, subtitle, and optional action.
struct PlaceholderView<Action: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder var action: Action

    init(
        icon: String,
        title: String,
        subtitle: String,
        @ViewBuilder action: () -> Action
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.action = action()
    }

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            action
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

extension PlaceholderView where Action == EmptyView {
    init(icon: String, title: String, subtitle: String) {
        self.init(icon: icon, title: title, subtitle: subtitle) {
            EmptyView()
        }
    }
}

// MARK: - Thumbnail View

struct ThumbnailView: View {
    let photo: PhotoItem
    @State private var thumbnail: NSImage?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if isLoading {
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        ProgressView()
                            .scaleEffect(0.5)
                    }
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.tertiary)
                    }
            }
        }
        .task(id: photo.url) {
            isLoading = true
            thumbnail = await ThumbnailCache.shared.thumbnail(
                for: photo.url,
                size: ShoeboxKit.gridThumbnailSize
            )
            isLoading = false
        }
    }
}

// MARK: - Previews

private func samplePhotos(count: Int = 12) -> [PhotoItem] {
    return [
        PhotoItem(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/.thumbnails/Dome Light.heic")),
        PhotoItem(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/.thumbnails/Dome Dark.heic")),
        PhotoItem(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/.thumbnails/Tree Dark.heic")),
        PhotoItem(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/.thumbnails/Big Sur Coastline.heic"))
    ]
}

#Preview("Photo Grid") {
    PhotoGridView(
        photos: samplePhotos(),
        isLoading: false,
        selectedPhoto: .constant(nil),
        similaritySourceID: .constant(nil),
        showingSlideshow: .constant(false),
        detailPhotoID: .constant(nil),
        showUnlockSheet: .constant(false),
        pendingRemoveLock: .constant(false)
    )
    .environmentObject(CollectionManager())
    .environmentObject(FavoritesManager())
    .frame(width: 800, height: 600)
}

#Preview("Photo Grid - Loading") {
    PhotoGridView(
        photos: [],
        isLoading: true,
        selectedPhoto: .constant(nil),
        similaritySourceID: .constant(nil),
        showingSlideshow: .constant(false),
        detailPhotoID: .constant(nil),
        showUnlockSheet: .constant(false),
        pendingRemoveLock: .constant(false)
    )
    .environmentObject(CollectionManager())
    .environmentObject(FavoritesManager())
    .frame(width: 800, height: 600)
}

#Preview("Photo Grid - Empty") {
    PhotoGridView(
        photos: [],
        isLoading: false,
        selectedPhoto: .constant(nil),
        similaritySourceID: .constant(nil),
        showingSlideshow: .constant(false),
        detailPhotoID: .constant(nil),
        showUnlockSheet: .constant(false),
        pendingRemoveLock: .constant(false)
    )
    .environmentObject(CollectionManager())
    .environmentObject(FavoritesManager())
    .frame(width: 800, height: 600)
}

#Preview("Thumbnail") {
    let photo = PhotoItem(url: URL(fileURLWithPath: "/tmp/sample_photo.jpg"))
    ThumbnailView(photo: photo)
        .frame(width: 200, height: 200)
}
