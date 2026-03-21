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
import UniformTypeIdentifiers

struct SidebarView: View {
    @EnvironmentObject var collectionManager: CollectionManager
    @EnvironmentObject var favoritesManager: FavoritesManager
    @State private var settingsCollectionID: UUID?
    @State private var selection: UUID?

    var body: some View {
        List(selection: $selection) {
            Section {
                SidebarRow(icon: "heart.fill", iconColor: .pink, title: "Favorites", count: favoritesManager.count)
                    .tag(CollectionManager.favoritesCollectionID)
            }

            Section {
                ForEach(collectionManager.sortedCollections) { collection in
                    SidebarRow(
                        icon: "folder.fill",
                        iconColor: .accentColor,
                        title: collection.name,
                        count: collection.photoCount,
                        isPasswordProtected: collection.isPasswordProtected,
                        isLocked: collectionManager.isLocked
                    )
                        .tag(collection.id)
                        .popover(
                            isPresented: Binding(
                                get: { settingsCollectionID == collection.id },
                                set: { if !$0 { settingsCollectionID = nil } }
                            ),
                            arrowEdge: .trailing
                        ) {
                            CollectionSettingsView(collection: collection)
                        }
                        .contextMenu {
                            Button {
                                settingsCollectionID = collection.id
                            } label: {
                                Label("Settings", systemImage: "gearshape")
                            }
                            Button {
                                NSWorkspace.shared.selectFile(
                                    nil,
                                    inFileViewerRootedAtPath: collection.path
                                )
                            } label: {
                                Label("Show in Finder", systemImage: "folder")
                            }
                            Divider()
                            Button(role: .destructive) {
                                removeCollection(collection)
                            } label: {
                                Label("Remove from Library", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                removeCollection(collection)
                            } label: {
                                Label("Delete", systemImage: "trash")
                                    .labelStyle(.iconOnly)
                            }
                        }
                }
                .onMove(perform: collectionManager.sortOrder.criterion == .manual ? { source, destination in
                    withAnimation {
                        collectionManager.moveCollection(fromOffsets: source, toOffset: destination)
                    }
                } : nil)
            } header: {
                Text("Collections")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 220)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Section("Sort By") {
                        ForEach(CollectionSortCriterion.allCases, id: \.self) { criterion in
                            Toggle(isOn: Binding(
                                get: { collectionManager.sortOrder.criterion == criterion },
                                set: { isOn in
                                    if isOn {
                                        withAnimation {
                                            collectionManager.sortOrder = CollectionSortOrder(
                                                criterion: criterion,
                                                ascending: true
                                            )
                                        }
                                    }
                                }
                            )) {
                                Label(criterion.label, systemImage: criterion.icon)
                            }
                        }
                    }

                    if collectionManager.sortOrder.criterion != .manual {
                        Section("Order") {
                            Toggle(isOn: Binding(
                                get: { collectionManager.sortOrder.ascending },
                                set: { _ in
                                    withAnimation {
                                        collectionManager.sortOrder.ascending = true
                                    }
                                }
                            )) {
                                Label("Ascending", systemImage: "arrow.up")
                            }

                            Toggle(isOn: Binding(
                                get: { !collectionManager.sortOrder.ascending },
                                set: { _ in
                                    withAnimation {
                                        collectionManager.sortOrder.ascending = false
                                    }
                                }
                            )) {
                                Label("Descending", systemImage: "arrow.down")
                            }
                        }
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease")
                }
                .menuIndicator(.hidden)
            }
        }
        .safeAreaBar(edge: .bottom) {
            HStack {
                Button(action: openFolder) {
                    Label("Add Folder", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderless)
                .padding(12)

                Spacer()
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
        .onAppear {
            selection = collectionManager.selectedCollectionID
        }
        .onChange(of: selection) { _, newValue in
            collectionManager.selectedCollectionID = newValue
        }
        .onChange(of: collectionManager.selectedCollectionID) { _, newValue in
            selection = newValue
        }
    }

    private func removeCollection(_ collection: PhotoCollection) {
        withAnimation {
            favoritesManager.removeFavorites(underPath: collection.path)
            collectionManager.removeCollection(collection)
        }
    }

    private func openFolder() {
        if let url = presentFolderPanel() {
            collectionManager.addCollection(from: url)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                guard let data = data as? Data,
                      let urlString = String(data: data, encoding: .utf8),
                      let url = URL(string: urlString)
                else { return }

                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                    DispatchQueue.main.async {
                        collectionManager.addCollection(from: url)
                    }
                }
            }
        }
        return true
    }
}

struct SidebarRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let count: Int
    var isPasswordProtected: Bool = false
    var isLocked: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .font(.title3)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .lineLimit(1)
                    .font(.body)

                Text(ShoeboxKit.photoCountLabel(count))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if isPasswordProtected {
                Image(systemName: isLocked ? "lock.fill" : "lock.open.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Previews

#Preview("Sidebar") {
    let manager = CollectionManager()
    SidebarView()
        .environmentObject(manager)
        .environmentObject(FavoritesManager())
        .frame(width: 260, height: 500)
}

#Preview("Sidebar Row") {
    SidebarRow(icon: "folder.fill", iconColor: .accentColor, title: "Vacation Photos", count: 42)
        .padding()
        .frame(width: 240)
}
