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

struct SettingsView: View {
    @EnvironmentObject var collectionManager: CollectionManager
    @AppStorage("collageGridSize") private var collageGridSize = 2
    @State private var showSetPasswordSheet = false

    private var lockMethodBinding: Binding<LockMethod> {
        Binding(
            get: { collectionManager.lockMethod },
            set: { collectionManager.setLockMethod($0) }
        )
    }

    var body: some View {
        Form {
            Section("Sidebar Grid") {
                Picker("Collage Style", selection: $collageGridSize) {
                    Text("2 \u{00d7} 2").tag(2)
                    Text("3 \u{00d7} 3").tag(3)
                }
                .pickerStyle(.radioGroup)
            }

            Section("Lock Method") {
                Picker(selection: lockMethodBinding) {
                    Text("Use Login Password").tag(LockMethod.loginPassword)
                    Text("Use Custom Password").tag(LockMethod.customPassword)
                } label: {
                    EmptyView()
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()

                if collectionManager.lockMethod == .customPassword {
                    Button(collectionManager.hasCustomPassword ? "Change Password…" : "Set Password…") {
                        showSetPasswordSheet = true
                    }
                    .padding(.leading, 20)
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 400, maxHeight: 280)
        .sheet(isPresented: $showSetPasswordSheet) {
            SetPasswordSheet { password in
                collectionManager.setCustomPassword(password)
            }
        }
    }
}

#Preview("Settings") {
    SettingsView()
        .environmentObject(CollectionManager())
}
