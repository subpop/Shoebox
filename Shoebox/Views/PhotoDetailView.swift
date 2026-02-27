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

struct PhotoDetailView: View {
    let photos: [PhotoItem]
    @Binding var isPresented: Bool
    @Binding var showInfo: Bool
    @Binding var scrolledPhotoID: PhotoItem.ID?
    let slideshowMode: Bool
    var onFindSimilar: ((String) -> Void)?
    @EnvironmentObject var favoritesManager: FavoritesManager

    @State private var displayOrder: [PhotoItem]
    @State private var currentImage: NSImage?
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var chromeVisible = true
    @State private var chromeHideTask: Task<Void, Never>?
    @FocusState private var isFocused: Bool

    @State private var isPlaying = true
    @State private var speed: Double = 7.0
    @State private var shuffle = false
    @State private var slideshowTask: Task<Void, Never>?

    private var interval: TimeInterval { 11.0 - speed }

    init(
        photos: [PhotoItem],
        isPresented: Binding<Bool>,
        showInfo: Binding<Bool>,
        scrolledPhotoID: Binding<PhotoItem.ID?>,
        slideshowMode: Bool = false,
        onFindSimilar: ((String) -> Void)? = nil
    ) {
        self.photos = photos
        self._isPresented = isPresented
        self._showInfo = showInfo
        self._scrolledPhotoID = scrolledPhotoID
        self.slideshowMode = slideshowMode
        self.onFindSimilar = onFindSimilar
        self._displayOrder = State(initialValue: photos)
    }

    private var currentIndex: Int {
        displayOrder.firstIndex(where: { $0.id == scrolledPhotoID }) ?? 0
    }

    private var currentPhoto: PhotoItem {
        let index = currentIndex
        guard index >= 0, index < displayOrder.count else {
            return photos[0]
        }
        return displayOrder[index]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            imageArea
                .ignoresSafeArea()

            if slideshowMode {
                slideshowOverlay
                    .opacity(chromeVisible ? 1 : 0)
                    .ignoresSafeArea()
            } else {
                navigationArrows
                    .opacity(chromeVisible ? 1 : 0)
                closeButton
                    .opacity(chromeVisible ? 1 : 0)
            }

            if showInfo && !slideshowMode {
                infoPanel
            }
        }
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onContinuousHover { phase in
            switch phase {
            case .active:
                resetChromeTimer()
            case .ended:
                break
            }
        }
        .onAppear {
            isFocused = true
            loadCurrentImage()
            resetChromeTimer()
            if slideshowMode {
                restartTimer()
            }
        }
        .onDisappear {
            slideshowTask?.cancel()
            chromeHideTask?.cancel()
        }
        .onChange(of: scrolledPhotoID) {
            scale = 1.0
            offset = .zero
            loadCurrentImage()
        }
        .onKeyPress(.leftArrow) {
            navigatePrevious()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            navigateNext()
            return .handled
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
        .onKeyPress(.space) {
            if slideshowMode {
                togglePlayback()
            } else {
                showInfo.toggle()
            }
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "f")) { _ in
            favoritesManager.toggleFavorite(currentPhoto)
            return .handled
        }
    }

    // MARK: - Image Area

    private var imageArea: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(displayOrder) { photo in
                    PhotoPageView(photo: photo, scale: $scale, offset: $offset)
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrolledPhotoID)
        .scrollDisabled(scale > 1.0)
        .scrollIndicators(.hidden)
    }

    // MARK: - Navigation Arrows (detail mode)

    private var navigationArrows: some View {
        HStack {
            GlassCircleButton(systemImage: "chevron.left") {
                navigatePrevious()
            }
            .opacity(currentIndex > 0 ? 1 : 0.3)
            .disabled(currentIndex == 0)
            .padding(.leading, 20)

            Spacer()

            GlassCircleButton(systemImage: "chevron.right") {
                navigateNext()
            }
            .opacity(currentIndex < displayOrder.count - 1 ? 1 : 0.3)
            .disabled(currentIndex >= displayOrder.count - 1)
            .padding(.trailing, 20)
        }
    }

    // MARK: - Close Button (detail mode)

    private var closeButton: some View {
        VStack {
            HStack {
                if onFindSimilar != nil {
                    GlassCircleButton(systemImage: "sparkle.magnifyingglass") {
                        onFindSimilar?(currentPhoto.id)
                    }
                    .help("Find Similar")
                }
                Spacer()
                GlassCircleButton(systemImage: "xmark") {
                    dismiss()
                }
            }
            .padding(20)
            Spacer()
        }
    }

    // MARK: - Slideshow Overlay

    private var slideshowOverlay: some View {
        VStack {
            HStack {
                Spacer()
                GlassCircleButton(systemImage: "xmark") {
                    dismiss()
                }
                .padding(20)
            }

            Spacer()

            VStack(spacing: 16) {
                if displayOrder.count <= 40 {
                    HStack(spacing: 4) {
                        ForEach(0..<displayOrder.count, id: \.self) { index in
                            Capsule()
                                .fill(index == currentIndex ? Color.white : Color.white.opacity(0.3))
                                .frame(height: 3)
                        }
                    }
                    .padding(.horizontal, 20)
                } else {
                    Text("\(currentIndex + 1) / \(displayOrder.count)")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.7))
                }

                HStack(spacing: 24) {
                    HStack(spacing: 6) {
                        Image(systemName: "tortoise.fill")
                            .foregroundStyle(.white.opacity(0.5))
                            .font(.caption)
                        Slider(value: $speed, in: 1...10, step: 0.5)
                            .frame(width: 80)
                            .tint(.white.opacity(0.7))
                            .onChange(of: speed) { _, _ in
                                if isPlaying { restartTimer() }
                            }
                        Image(systemName: "hare.fill")
                            .foregroundStyle(.white.opacity(0.5))
                            .font(.caption)
                    }

                    Button {
                        toggleShuffle()
                    } label: {
                        Image(systemName: "shuffle")
                            .font(.caption)
                            .foregroundStyle(shuffle ? .orange : .white.opacity(0.5))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    HStack(spacing: 16) {
                        GlassCircleButton(systemImage: "backward.fill", size: 36, font: .callout, shadow: false) {
                            navigatePrevious()
                        }

                        GlassCircleButton(systemImage: isPlaying ? "pause.fill" : "play.fill", size: 48, font: .title3, shadow: false) {
                            togglePlayback()
                        }

                        GlassCircleButton(systemImage: "forward.fill", size: 36, font: .callout, shadow: false) {
                            navigateNext()
                        }
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Text(currentPhoto.name)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)

                        FavoriteButton(photo: currentPhoto, inactiveColor: .white.opacity(0.5))
                            .font(.callout)
                    }
                    .frame(width: 160, alignment: .trailing)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .backgroundExtensionEffect()
        }
    }

    // MARK: - Info Panel

    private var infoPanel: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Photo Info")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Divider()

                    InfoRow(label: "Name", value: currentPhoto.name)
                    InfoRow(label: "Format", value: currentPhoto.fileExtension)
                    InfoRow(label: "Size", value: currentPhoto.fileSizeFormatted)
                    InfoRow(label: "Modified", value: currentPhoto.dateModified.formatted(date: .abbreviated, time: .shortened))

                    if let image = currentImage {
                        let rep = image.representations.first
                        let w = rep?.pixelsWide ?? Int(image.size.width)
                        let h = rep?.pixelsHigh ?? Int(image.size.height)
                        InfoRow(label: "Dimensions", value: "\(w) \u{00D7} \(h) px")
                    }

                    InfoRow(label: "Path", value: currentPhoto.url.path, url: currentPhoto.url)
                }
                .padding(16)
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
                .frame(width: 300)
                .padding(20)
            }
        }
    }

    // MARK: - Chrome Visibility

    private func resetChromeTimer() {
        chromeHideTask?.cancel()
        withAnimation(.easeOut(duration: 0.25)) {
            chromeVisible = true
        }
        chromeHideTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.5)) {
                chromeVisible = false
            }
        }
    }

    // MARK: - Navigation

    private func navigatePrevious() {
        guard !displayOrder.isEmpty else { return }
        if slideshowMode {
            let atStart = currentIndex == 0
            let prevIndex = atStart
                ? displayOrder.count - 1
                : currentIndex - 1
            if atStart {
                scrolledPhotoID = displayOrder[prevIndex].id
            } else {
                withAnimation(.easeInOut(duration: 0.25)) {
                    scrolledPhotoID = displayOrder[prevIndex].id
                }
            }
            if isPlaying { restartTimer() }
        } else {
            guard currentIndex > 0 else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                scrolledPhotoID = displayOrder[currentIndex - 1].id
            }
        }
    }

    private func navigateNext() {
        guard !displayOrder.isEmpty else { return }
        if slideshowMode {
            let atEnd = currentIndex >= displayOrder.count - 1
            if atEnd && shuffle {
                reshuffleFromCurrent()
            }
            let nextIndex: Int
            if atEnd {
                nextIndex = shuffle && displayOrder.count > 1 ? 1 : 0
            } else {
                nextIndex = currentIndex + 1
            }
            if atEnd {
                scrolledPhotoID = displayOrder[nextIndex].id
            } else {
                withAnimation(.easeInOut(duration: 0.25)) {
                    scrolledPhotoID = displayOrder[nextIndex].id
                }
            }
            if isPlaying { restartTimer() }
        } else {
            guard currentIndex < displayOrder.count - 1 else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                scrolledPhotoID = displayOrder[currentIndex + 1].id
            }
        }
    }

    // MARK: - Slideshow Control

    private func togglePlayback() {
        isPlaying.toggle()
        if isPlaying {
            restartTimer()
        } else {
            slideshowTask?.cancel()
        }
    }

    private func restartTimer() {
        slideshowTask?.cancel()
        slideshowTask = Task {
            while !Task.isCancelled && isPlaying {
                try? await Task.sleep(for: .seconds(interval))
                if !Task.isCancelled {
                    await MainActor.run {
                        navigateNext()
                    }
                }
            }
        }
    }

    private func toggleShuffle() {
        shuffle.toggle()
        if shuffle {
            reshuffleFromCurrent()
        } else {
            displayOrder = photos
        }
    }

    private func reshuffleFromCurrent() {
        let currentID = scrolledPhotoID
        guard let current = photos.first(where: { $0.id == currentID }) else {
            displayOrder = photos.shuffled()
            return
        }
        var remaining = photos.filter { $0.id != currentID }
        remaining.shuffle()
        displayOrder = [current] + remaining
    }

    private func dismiss() {
        slideshowTask?.cancel()
        chromeHideTask?.cancel()
        isPresented = false
    }

    private func loadCurrentImage() {
        currentImage = nil
        let photo = currentPhoto
        Task {
            if let image = NSImage(contentsOf: photo.url) {
                await MainActor.run {
                    withAnimation(.easeIn(duration: 0.15)) {
                        currentImage = image
                    }
                }
            }
        }
    }
}

// MARK: - Photo Page

private struct PhotoPageView: View {
    let photo: PhotoItem
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(magnificationGesture)
                    .gesture(dragGesture)
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
            }
        }
        .task(id: photo.id) {
            image = NSImage(contentsOf: photo.url)
        }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = max(0.5, min(5.0, value))
            }
            .onEnded { _ in
                withAnimation(.spring(duration: 0.3)) {
                    if scale < 1.0 {
                        scale = 1.0
                        offset = .zero
                    }
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1.0 {
                    offset = value.translation
                }
            }
            .onEnded { _ in
                if scale <= 1.0 {
                    withAnimation(.spring(duration: 0.3)) {
                        offset = .zero
                    }
                }
            }
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String
    var url: URL? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Text(value)
                    .font(.callout)
                    .lineLimit(1)
                    .textSelection(.enabled)
                    .truncationMode(.middle)
                if let url {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    } label: {
                        Image(systemName: "arrow.forward.circle.fill")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Reveal in Finder")
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Photo Detail") {
    let photos = [
        PhotoItem(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/.thumbnails/Dome Light.heic")),
        PhotoItem(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/.thumbnails/Dome Dark.heic")),
        PhotoItem(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/.thumbnails/Tree Dark.heic")),
        PhotoItem(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/.thumbnails/Big Sur Coastline.heic")),
    ]
    PhotoDetailView(
        photos: photos,
        isPresented: .constant(true),
        showInfo: .constant(false),
        scrolledPhotoID: .constant(photos[0].id)
    )
    .environmentObject(FavoritesManager())
    .frame(width: 900, height: 600)
}

#Preview("Slideshow") {
    let photos = (0..<10).map { i in
        PhotoItem(url: URL(fileURLWithPath: "/tmp/slideshow_photo_\(i + 1).jpg"))
    }
    PhotoDetailView(
        photos: photos,
        isPresented: .constant(true),
        showInfo: .constant(false),
        scrolledPhotoID: .constant(photos[0].id),
        slideshowMode: true
    )
    .environmentObject(FavoritesManager())
    .frame(width: 900, height: 600)
}

#Preview("Info Row") {
    VStack(alignment: .leading, spacing: 12) {
        InfoRow(label: "Name", value: "sunset_beach.jpg")
        InfoRow(label: "Size", value: "3.2 MB")
        InfoRow(label: "Dimensions", value: "4032 \u{00D7} 3024 px")
    }
    .padding()
    .frame(width: 280)
}
