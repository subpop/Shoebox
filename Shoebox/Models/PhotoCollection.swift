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

struct PhotoCollection: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var path: String
    var bookmarkData: Data?
    var dateAdded: Date
    var photoCount: Int
    var recurseSubdirectories: Bool

    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        bookmarkData: Data? = nil,
        photoCount: Int = 0,
        recurseSubdirectories: Bool = false
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.bookmarkData = bookmarkData
        self.dateAdded = Date()
        self.photoCount = photoCount
        self.recurseSubdirectories = recurseSubdirectories
    }
}
