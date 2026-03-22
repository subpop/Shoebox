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

@main
struct ShoeboxApp: App {
    @StateObject private var collectionManager = CollectionManager()
    @StateObject private var favoritesManager = FavoritesManager()
    @Environment(\.openWindow) private var openWindow

    init() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(collectionManager)
                .environmentObject(favoritesManager)
        }
        .defaultSize(width: 800, height: 500)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Folder…") {
                    NotificationCenter.default.post(name: .openFolder, object: nil)
                }
                .keyboardShortcut("o")
            }
            SidebarCommands()
            CommandGroup(after: .singleWindowList) {
                Button("Shoebox", systemImage: "macwindow") {
                    if let window = NSApplication.shared.windows.first(where: { $0.canBecomeMain }) {
                        window.deminiaturize(nil)
                        window.makeKeyAndOrderFront(nil)
                        NSApplication.shared.activate()
                    } else {
                        openWindow(id: "main")
                    }
                }
                .keyboardShortcut("0")
            }
            CommandGroup(after: .help) {
                Button("Provide Feedback...") {
                    let url = URL(string: "https://github.com/subpop/Shoebox/issues")!
                    NSWorkspace.shared.open(url)
                }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(collectionManager)
        }
    }
}

extension Notification.Name {
    static let openFolder = Notification.Name("ShoeboxOpenFolder")
    static let cachesCleared = Notification.Name("ShoeboxCachesCleared")
}

/// Presents an NSOpenPanel configured for folder selection and returns the chosen URL.
@MainActor func presentFolderPanel() -> URL? {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.message = "Select a folder containing photos"
    panel.prompt = "Open"
    guard panel.runModal() == .OK else { return nil }
    return panel.url
}
