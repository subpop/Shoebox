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

struct ShareButton: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(frame: .zero)
        button.bezelStyle = .toolbar
        button.image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: "Share")
        button.isBordered = true
        button.contentTintColor = .labelColor
        button.target = context.coordinator
        button.action = #selector(Coordinator.showPicker(_:))
        button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        context.coordinator.url = url
    }

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    class Coordinator: NSObject, NSSharingServicePickerDelegate {
        var url: URL

        init(url: URL) { self.url = url }

        @MainActor @objc func showPicker(_ sender: NSButton) {
            let picker = NSSharingServicePicker(items: [url])
            picker.delegate = self
            picker.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }

        func sharingServicePicker(
            _ sharingServicePicker: NSSharingServicePicker,
            sharingServicesForItems items: [Any],
            proposedSharingServices proposedServices: [NSSharingService]
        ) -> [NSSharingService] {
            var custom: [NSSharingService] = []

            let setWallpaper = NSSharingService(
                title: "Set as Desktop Wallpaper",
                image: NSImage(systemSymbolName: "desktopcomputer", accessibilityDescription: nil)!,
                alternateImage: nil
            ) { [url = self.url] in
                guard let screen = NSScreen.main else { return }
                try? NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
            }
            custom.append(setWallpaper)

            return custom + proposedServices
        }
    }
}
