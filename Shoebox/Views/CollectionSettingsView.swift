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

struct CollectionSettingsView: View {
    @EnvironmentObject var collectionManager: CollectionManager
    @State var collection: PhotoCollection

    var body: some View {
        Form {
            Section {
                Toggle("Include subfolders", isOn: $collection.recurseSubdirectories)
            }

            if collectionManager.hasPassword {
                Section {
                    Toggle("Password protected", isOn: $collection.isPasswordProtected)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 280)
        .fixedSize()
        .onChange(of: collection.recurseSubdirectories) { _, _ in
            collectionManager.updateCollection(collection)
        }
        .onChange(of: collection.isPasswordProtected) { _, _ in
            collectionManager.updateCollection(collection)
        }
    }
}

#Preview("Collection Settings") {
    CollectionSettingsView(collection: PhotoCollection(
        name: "Vacation Photos",
        path: "/Users/demo/Pictures/Vacation",
        photoCount: 42
    ))
    .environmentObject(CollectionManager())
}
