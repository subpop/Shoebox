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

@MainActor
struct CollectionManagerTests {
    /// Helper method for creating testable UserDefaults
    private func makeDefaults() -> UserDefaults {
        let suiteName = "CollectionManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    /// Helper method for creating test collections
    private func makeCollection(
        name: String = "Test",
        path: String = "/photos/test",
        isPasswordProtected: Bool = false
    ) -> PhotoCollection {
        PhotoCollection(
            name: name,
            path: path,
            isPasswordProtected: isPasswordProtected
        )
    }

    // MARK: - Password Hashing

    // Verify hashPassword produces the correct SHA-256 hex digest.
    @Test func hashPasswordProducesSHA256() {
        let hash = CollectionManager.hashPassword("hello")
        // SHA-256 of "hello" is a known value
        #expect(hash == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
        #expect(hash.count == 64) // 256 bits = 64 hex chars
    }

    // Verify hashing the same input twice yields identical output.
    @Test func hashPasswordDeterministic() {
        let hash1 = CollectionManager.hashPassword("test123")
        let hash2 = CollectionManager.hashPassword("test123")
        #expect(hash1 == hash2)
    }

    // Verify different passwords produce different hashes.
    @Test func hashPasswordDifferentInputsDifferentOutputs() {
        let hash1 = CollectionManager.hashPassword("password1")
        let hash2 = CollectionManager.hashPassword("password2")
        #expect(hash1 != hash2)
    }

    // MARK: - Custom Password

    // Verify setting a custom password stores the hash and unlocks the manager.
    @Test func setAndVerifyCustomPassword() {
        let manager = CollectionManager(defaults: makeDefaults())

        #expect(!manager.hasCustomPassword)

        manager.setCustomPassword("secret")
        #expect(manager.hasCustomPassword)
        #expect(manager.isUnlocked)
    }

    // Verify unlock succeeds when the correct password is provided.
    @Test func unlockWithCorrectPassword() {
        let manager = CollectionManager(defaults: makeDefaults())
        manager.setCustomPassword("secret")
        manager.lock()

        // Need a locked collection for lock() to take effect
        let collection = makeCollection(isPasswordProtected: true)
        manager.collections.append(collection)
        manager.selectedCollectionID = collection.id
        manager.lock()

        let result = manager.unlock(password: "secret")
        #expect(result)
        #expect(manager.isUnlocked)
    }

    // Verify unlock fails and stays locked when the wrong password is provided.
    @Test func unlockWithWrongPassword() {
        let manager = CollectionManager(defaults: makeDefaults())
        manager.setCustomPassword("secret")

        let collection = makeCollection(isPasswordProtected: true)
        manager.collections.append(collection)
        manager.selectedCollectionID = collection.id
        manager.lock()

        let result = manager.unlock(password: "wrong")
        #expect(!result)
        #expect(!manager.isUnlocked)
    }

    // Verify clearing the custom password removes it from defaults.
    @Test func clearCustomPassword() {
        let manager = CollectionManager(defaults: makeDefaults())
        manager.setCustomPassword("secret")
        #expect(manager.hasCustomPassword)

        manager.clearCustomPassword()
        #expect(!manager.hasCustomPassword)
    }

    // MARK: - Lock Method

    // Verify switching to loginPassword lock method also clears any stored custom password.
    @Test func setLockMethodToLoginPasswordClearsCustomPassword() {
        let defaults = makeDefaults()
        let manager = CollectionManager(defaults: defaults)
        manager.setCustomPassword("secret")
        #expect(manager.hasCustomPassword)

        manager.setLockMethod(.loginPassword)
        #expect(manager.lockMethod == .loginPassword)
        #expect(!manager.hasCustomPassword)
    }

    // Verify the selected lock method is persisted to UserDefaults.
    @Test func setLockMethodPersists() {
        let defaults = makeDefaults()
        let manager = CollectionManager(defaults: defaults)
        manager.setLockMethod(.customPassword)

        let stored = defaults.string(forKey: ShoeboxKit.lockMethodKey)
        #expect(stored == LockMethod.customPassword.rawValue)
    }

    // MARK: - Lock State

    // Verify isLocked is false when no collections are password-protected.
    @Test func isLockedRequiresLockedCollections() {
        let manager = CollectionManager(defaults: makeDefaults())
        // No collections, so not locked
        #expect(!manager.isLocked)

        let unprotected = makeCollection(isPasswordProtected: false)
        manager.collections.append(unprotected)
        #expect(!manager.isLocked)
    }

    // Verify isLocked is true when a password-protected collection exists and hasn't been unlocked.
    @Test func isLockedWithProtectedCollection() {
        let manager = CollectionManager(defaults: makeDefaults())
        let protected = makeCollection(isPasswordProtected: true)
        manager.collections.append(protected)

        #expect(manager.isLocked)
        #expect(!manager.isUnlocked)
    }

    // Verify calling lock() is a no-op when no collections are password-protected.
    @Test func lockDoesNothingWithoutLockedCollections() {
        let manager = CollectionManager(defaults: makeDefaults())
        manager.setCustomPassword("secret") // sets isUnlocked = true
        #expect(manager.isUnlocked)

        manager.lock() // no locked collections, should be no-op
        #expect(manager.isUnlocked)
    }

    // MARK: - Collection Management

    // Verify adding and removing password protection on the selected collection toggles the flag.
    @Test func addAndRemoveLockOnSelectedCollection() {
        let manager = CollectionManager(defaults: makeDefaults())
        let collection = makeCollection()
        manager.collections.append(collection)
        manager.selectedCollectionID = collection.id

        #expect(!manager.isSelectedCollectionPasswordProtected)

        manager.addLockToSelectedCollection()
        #expect(manager.isSelectedCollectionPasswordProtected)

        manager.removeLockFromSelectedCollection()
        #expect(!manager.isSelectedCollectionPasswordProtected)
    }

    // Verify updatePhotoCount sets the correct count on the matching collection.
    @Test func updatePhotoCount() {
        let manager = CollectionManager(defaults: makeDefaults())
        let collection = makeCollection()
        manager.collections.append(collection)

        manager.updatePhotoCount(for: collection.id, count: 42)
        #expect(manager.collections.first?.photoCount == 42)
    }

    // Verify updateCollection replaces the collection in-place by matching ID.
    @Test func updateCollection() {
        let manager = CollectionManager(defaults: makeDefaults())
        var collection = makeCollection(name: "Original")
        manager.collections.append(collection)

        collection.name = "Renamed"
        manager.updateCollection(collection)

        #expect(manager.collections.first?.name == "Renamed")
    }

    // Verify moveCollection reorders collections correctly.
    @Test func moveCollection() {
        let manager = CollectionManager(defaults: makeDefaults())
        let c1 = makeCollection(name: "First", path: "/a")
        let c2 = makeCollection(name: "Second", path: "/b")
        manager.collections.append(c1)
        manager.collections.append(c2)

        manager.moveCollection(fromOffsets: IndexSet(integer: 1), toOffset: 0)
        #expect(manager.collections[0].name == "Second")
        #expect(manager.collections[1].name == "First")
    }

    // MARK: - Favorites Selection

    // Verify isFavoritesSelected returns true only when the favorites UUID is selected.
    @Test func isFavoritesSelected() {
        let manager = CollectionManager(defaults: makeDefaults())
        manager.selectedCollectionID = CollectionManager.favoritesCollectionID
        #expect(manager.isFavoritesSelected)

        manager.selectedCollectionID = UUID()
        #expect(!manager.isFavoritesSelected)
    }

    // Verify selectedCollection returns the collection matching selectedCollectionID.
    @Test func selectedCollectionReturnsCorrectCollection() {
        let manager = CollectionManager(defaults: makeDefaults())
        let collection = makeCollection()
        manager.collections.append(collection)
        manager.selectedCollectionID = collection.id

        #expect(manager.selectedCollection?.id == collection.id)
    }

    // Verify selectedCollection returns nil when no collection matches the selected ID.
    @Test func selectedCollectionReturnsNilWhenNoMatch() {
        let manager = CollectionManager(defaults: makeDefaults())
        manager.selectedCollectionID = UUID()
        #expect(manager.selectedCollection == nil)
    }
}
