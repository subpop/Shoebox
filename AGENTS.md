# AGENTS.md

Shoebox is a macOS SwiftUI photo browser with a WidgetKit extension. Built with Xcode (`Shoebox.xcodeproj`), no SPM or CocoaPods dependencies.

## Architecture

- **Models** are plain structs (`PhotoItem`, `PhotoCollection`). `PhotoCollection` is `Codable`.
- **Services** are `ObservableObject` classes or Swift actors (`CollectionManager`, `PhotoLoader`, `ThumbnailCache`, `SmartCropper`).
- **Views** are SwiftUI. Avoid UIKit/AppKit unless necessary.
- **Shared/** contains code imported by both the app and widget targets. Keep shared utilities there.

## Conventions

- Image format support is defined once in `ShoeboxKit.imageExtensions`.
- Collections persist as JSON in shared `UserDefaults` via App Group.
- Folder access uses security-scoped bookmarks for sandbox compatibility.
- The widget reads pre-exported thumbnails from the App Group container; it does not access user folders directly.
