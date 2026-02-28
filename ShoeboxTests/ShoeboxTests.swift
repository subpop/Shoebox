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

import Testing
import Foundation
@testable import Shoebox

struct PhotoCollectionTests {
    // Verify default initializer sets expected values for all optional properties.
    @Test func defaultInitValues() {
        let collection = PhotoCollection(name: "Vacation", path: "/photos/vacation")

        #expect(collection.name == "Vacation")
        #expect(collection.path == "/photos/vacation")
        #expect(collection.bookmarkData == nil)
        #expect(collection.photoCount == 0)
        #expect(collection.recurseSubdirectories == false)
        #expect(collection.isPasswordProtected == false)
    }

    // Verify encoding to JSON and decoding back preserves all properties.
    @Test func codableRoundTrip() throws {
        let original = PhotoCollection(
            name: "Test",
            path: "/test/path",
            photoCount: 42,
            recurseSubdirectories: true,
            isPasswordProtected: true
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PhotoCollection.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.path == original.path)
        #expect(decoded.photoCount == original.photoCount)
        #expect(decoded.recurseSubdirectories == original.recurseSubdirectories)
        #expect(decoded.isPasswordProtected == original.isPasswordProtected)
    }

    // Verify collections can be stored in a Set and deduplicated by identity.
    @Test func hashableConformance() {
        let c1 = PhotoCollection(name: "A", path: "/a")
        let c2 = PhotoCollection(name: "B", path: "/b")

        var set: Set<PhotoCollection> = [c1, c2]
        #expect(set.count == 2)

        // Inserting same instance again shouldn't increase count
        set.insert(c1)
        #expect(set.count == 2)
    }
}

struct PhotoItemTests {
    // Verify PhotoItem extracts name, id, and extension from the file URL.
    @Test func initFromURL() {
        let url = URL(fileURLWithPath: "/photos/sunset.jpg")
        let item = PhotoItem(url: url)

        #expect(item.url == url)
        #expect(item.name == "sunset")
        #expect(item.id == url.absoluteString)
        #expect(item.fileExtension == "JPG")
    }

    // Verify two PhotoItems with the same URL are considered equal.
    @Test func equalityBasedOnURL() {
        let url = URL(fileURLWithPath: "/photos/test.jpg")
        let item1 = PhotoItem(url: url)
        let item2 = PhotoItem(url: url)

        #expect(item1 == item2)
    }

    // Verify two PhotoItems with different URLs are not equal.
    @Test func differentURLsAreNotEqual() {
        let item1 = PhotoItem(url: URL(fileURLWithPath: "/a.jpg"))
        let item2 = PhotoItem(url: URL(fileURLWithPath: "/b.jpg"))

        #expect(item1 != item2)
    }

    // Verify fileSizeFormatted returns a non-empty human-readable string.
    @Test func fileSizeFormattedReturnsString() {
        let item = PhotoItem(url: URL(fileURLWithPath: "/test.jpg"))
        // Just verify it returns a non-empty string (actual file may not exist, so size is 0)
        #expect(!item.fileSizeFormatted.isEmpty)
    }
}
