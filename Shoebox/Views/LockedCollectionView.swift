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

struct LockedCollectionView: View {
    @EnvironmentObject var collectionManager: CollectionManager
    @State private var password = ""
    @State private var errorShake = false
    @State private var showRemovePasswordSheet = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("This Collection is Locked")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("Enter your password to view this collection.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                    .focused($focused)
                    .onSubmit { attemptUnlock() }
                    .offset(x: errorShake ? -6 : 0)

                Button("Unlock") { attemptUnlock() }
                    .disabled(password.isEmpty)
            }

            Button("Remove Password") {
                showRemovePasswordSheet = true
            }
            .buttonStyle(.borderless)
            .font(.callout)
            .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { focused = true }
        .sheet(isPresented: $showRemovePasswordSheet) {
            RemovePasswordSheet()
        }
    }

    private func attemptUnlock() {
        guard !password.isEmpty else { return }
        if collectionManager.unlock(password: password) {
            password = ""
        } else {
            withAnimation(.default.repeatCount(3, autoreverses: true).speed(6)) {
                errorShake = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                errorShake = false
            }
            password = ""
            focused = true
        }
    }
}

// MARK: - Set Password Sheet

struct SetPasswordSheet: View {
    var onSet: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var confirmPassword = ""
    @FocusState private var focused: Field?

    private enum Field { case password, confirm }

    private var passwordsMatch: Bool {
        !password.isEmpty && password == confirmPassword
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("Set a Password")
                .font(.headline)

            Text("This password will be required to view your collections.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            SecureField("Password", text: $password)
                .focused($focused, equals: .password)
                .textFieldStyle(.roundedBorder)

            SecureField("Confirm Password", text: $confirmPassword)
                .focused($focused, equals: .confirm)
                .textFieldStyle(.roundedBorder)

            if !confirmPassword.isEmpty && !passwordsMatch {
                Text("Passwords don't match")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Set Password") {
                    onSet(password)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!passwordsMatch)
            }
        }
        .padding(24)
        .frame(width: 280)
        .onAppear { focused = .password }
    }
}

// MARK: - Remove Password Sheet

struct RemovePasswordSheet: View {
    @EnvironmentObject var collectionManager: CollectionManager

    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var errorShake = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.open.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("Remove Password Lock")
                .font(.headline)

            Text("Enter the current password to remove the lock.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            SecureField("Current Password", text: $password)
                .focused($focused)
                .textFieldStyle(.roundedBorder)
                .offset(x: errorShake ? -6 : 0)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Remove Lock") {
                    if collectionManager.removePassword(verifying: password) {
                        dismiss()
                    } else {
                        withAnimation(.default.repeatCount(3, autoreverses: true).speed(6)) {
                            errorShake = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            errorShake = false
                        }
                        password = ""
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(password.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 280)
        .onAppear { focused = true }
    }
}

// MARK: - Unlock Sheet

struct UnlockSheet: View {
    @EnvironmentObject var collectionManager: CollectionManager

    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var errorShake = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("Unlock Collections")
                .font(.headline)

            Text("Enter your password to view protected collections.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            SecureField("Password", text: $password)
                .focused($focused)
                .textFieldStyle(.roundedBorder)
                .onSubmit { attemptUnlock() }
                .offset(x: errorShake ? -6 : 0)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Unlock") { attemptUnlock() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(password.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 280)
        .onAppear { focused = true }
    }

    private func attemptUnlock() {
        guard !password.isEmpty else { return }
        if collectionManager.unlock(password: password) {
            dismiss()
        } else {
            withAnimation(.default.repeatCount(3, autoreverses: true).speed(6)) {
                errorShake = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                errorShake = false
            }
            password = ""
        }
    }
}

#Preview("Locked") {
    LockedCollectionView()
        .environmentObject(CollectionManager())
        .frame(width: 600, height: 400)
}
