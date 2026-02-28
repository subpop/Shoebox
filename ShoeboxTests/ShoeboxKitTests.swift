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

struct ShoeboxKitTests {
    // MARK: - photoCountLabel

    // Verify singular form "1 photo" is used for a count of 1.
    @Test func photoCountLabelSingular() {
        #expect(ShoeboxKit.photoCountLabel(1) == "1 photo")
    }

    // Verify plural form "N photos" is used for counts other than 1.
    @Test func photoCountLabelPlural() {
        #expect(ShoeboxKit.photoCountLabel(0) == "0 photos")
        #expect(ShoeboxKit.photoCountLabel(2) == "2 photos")
        #expect(ShoeboxKit.photoCountLabel(100) == "100 photos")
    }

    // MARK: - Data.sha256Hex

    // Verify SHA-256 digest matches the known hash for "hello".
    @Test func sha256HexKnownValue() {
        let data = Data("hello".utf8)
        #expect(data.sha256Hex == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
    }

    // Verify SHA-256 of empty data produces the known empty-input constant.
    @Test func sha256HexEmptyData() {
        let data = Data()
        // SHA-256 of empty input is a known constant
        #expect(data.sha256Hex == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    // Verify the hex string is always 64 characters (256 bits).
    @Test func sha256HexProduces64Characters() {
        let data = Data("test".utf8)
        #expect(data.sha256Hex.count == 64)
    }

    // Verify the hex output uses only lowercase characters.
    @Test func sha256HexIsLowercase() {
        let data = Data("test".utf8)
        #expect(data.sha256Hex == data.sha256Hex.lowercased())
    }

    // MARK: - favoritesCollectionID

    // Verify the well-known favorites collection UUID doesn't change.
    @Test func favoritesCollectionIDIsStable() {
        let id = ShoeboxKit.favoritesCollectionID
        #expect(id == UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
    }

    // MARK: - imageURLs

    // Verify imageURLs returns only files with image extensions from a directory.
    @Test func imageURLsFindsImagesInDirectory() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShoeboxKitTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create test files
        let jpgFile = tempDir.appendingPathComponent("photo.jpg")
        let pngFile = tempDir.appendingPathComponent("image.png")
        let txtFile = tempDir.appendingPathComponent("notes.txt")

        try Data().write(to: jpgFile)
        try Data().write(to: pngFile)
        try Data().write(to: txtFile)

        let urls = ShoeboxKit.imageURLs(in: tempDir)
        let names = Set(urls.map { $0.lastPathComponent })

        #expect(names.contains("photo.jpg"))
        #expect(names.contains("image.png"))
        #expect(!names.contains("notes.txt"))
    }

    // Verify recursive mode finds nested images and non-recursive mode skips them.
    @Test func imageURLsRespectsRecursiveFlag() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShoeboxKitTests-\(UUID().uuidString)")
        let subDir = tempDir.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let topFile = tempDir.appendingPathComponent("top.jpg")
        let subFile = subDir.appendingPathComponent("nested.jpg")
        try Data().write(to: topFile)
        try Data().write(to: subFile)

        let recursive = ShoeboxKit.imageURLs(in: tempDir, recursive: true)
        #expect(recursive.count == 2)

        let nonRecursive = ShoeboxKit.imageURLs(in: tempDir, recursive: false)
        #expect(nonRecursive.count == 1)
        #expect(nonRecursive.first?.lastPathComponent == "top.jpg")
    }

    // Verify dot-prefixed hidden files are excluded from results.
    @Test func imageURLsSkipsHiddenFiles() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShoeboxKitTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let visible = tempDir.appendingPathComponent("visible.jpg")
        let hidden = tempDir.appendingPathComponent(".hidden.jpg")
        try Data().write(to: visible)
        try Data().write(to: hidden)

        let urls = ShoeboxKit.imageURLs(in: tempDir)
        #expect(urls.count == 1)
        #expect(urls.first?.lastPathComponent == "visible.jpg")
    }
}
