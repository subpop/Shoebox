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

struct ImageIndexerTests {
    // MARK: - Search

    // Verify search finds photos by matching classification tags.
    @Test func searchMatchesTags() async {
        let indexer = ImageIndexer()

        let entry = IndexEntry(tags: ["beach", "sunset"], text: [], fileModified: Date())
        await indexer.storeEntryForTesting(entry, forID: "photo1")

        let results = await indexer.search(query: "beach", in: Set(["photo1"]))
        #expect(results.contains("photo1"))
    }

    // Verify search finds photos by matching recognized text.
    @Test func searchMatchesText() async {
        let indexer = ImageIndexer()

        let entry = IndexEntry(tags: [], text: ["Welcome Home"], fileModified: Date())
        await indexer.storeEntryForTesting(entry, forID: "photo1")

        let results = await indexer.search(query: "welcome", in: Set(["photo1"]))
        #expect(results.contains("photo1"))
    }

    // Verify search matching ignores letter case.
    @Test func searchIsCaseInsensitive() async {
        let indexer = ImageIndexer()

        let entry = IndexEntry(tags: ["Mountain"], text: [], fileModified: Date())
        await indexer.storeEntryForTesting(entry, forID: "photo1")

        let results = await indexer.search(query: "mountain", in: Set(["photo1"]))
        #expect(results.contains("photo1"))
    }

    // Verify search returns empty results when no tags or text match the query.
    @Test func searchNoMatch() async {
        let indexer = ImageIndexer()

        let entry = IndexEntry(tags: ["beach"], text: ["hello"], fileModified: Date())
        await indexer.storeEntryForTesting(entry, forID: "photo1")

        let results = await indexer.search(query: "mountain", in: Set(["photo1"]))
        #expect(results.isEmpty)
    }

    // Verify search only considers the photo IDs passed in the scope set.
    @Test func searchOnlySearchesRequestedIDs() async {
        let indexer = ImageIndexer()

        let entry1 = IndexEntry(tags: ["beach"], text: [], fileModified: Date())
        let entry2 = IndexEntry(tags: ["beach"], text: [], fileModified: Date())
        await indexer.storeEntryForTesting(entry1, forID: "photo1")
        await indexer.storeEntryForTesting(entry2, forID: "photo2")

        // Only search in photo1's scope
        let results = await indexer.search(query: "beach", in: Set(["photo1"]))
        #expect(results == Set(["photo1"]))
    }

    // Verify an empty query string matches nothing.
    @Test func searchWithEmptyQuery() async {
        let indexer = ImageIndexer()

        let entry = IndexEntry(tags: ["beach"], text: ["hello"], fileModified: Date())
        await indexer.storeEntryForTesting(entry, forID: "photo1")

        // Empty string does not match any tags or text
        let results = await indexer.search(query: "", in: Set(["photo1"]))
        #expect(results.isEmpty)
    }

    // MARK: - IndexProgress

    // Verify isActive reflects whether indexing is still in progress.
    @Test func indexProgressIsActive() {
        let active = IndexProgress(completed: 5, total: 10)
        #expect(active.isActive)

        let done = IndexProgress(completed: 10, total: 10)
        #expect(!done.isActive)

        let empty = IndexProgress(completed: 0, total: 0)
        #expect(!empty.isActive)
    }

    // MARK: - IndexEntry Codable

    // Verify IndexEntry can be encoded to JSON and decoded back without data loss.
    @Test func indexEntryRoundTrips() throws {
        let entry = IndexEntry(
            tags: ["sky", "cloud"],
            text: ["Sign Text"],
            fileModified: Date(timeIntervalSince1970: 1000000),
            featurePrintData: nil
        )

        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(IndexEntry.self, from: data)

        #expect(decoded.tags == entry.tags)
        #expect(decoded.text == entry.text)
        #expect(decoded.fileModified == entry.fileModified)
        #expect(decoded.featurePrintData == nil)
    }
}
