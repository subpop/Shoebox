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

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.stack")
                .font(.system(size: 64))
                .foregroundStyle(.quaternary)

            Text("Welcome to Shoebox")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Text("Add a folder to start browsing your photos")
                .font(.title3)
                .foregroundStyle(.tertiary)

            Button {
                NotificationCenter.default.post(name: .openFolder, object: nil)
            } label: {
                Label("Add Folder", systemImage: "folder.badge.plus")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 8)

            HStack(spacing: 6) {
                Image(systemName: "cursorarrow.and.square.on.square.dashed")
                    .foregroundStyle(.quaternary)
                Text("Or drag a folder into the sidebar")
                    .font(.callout)
                    .foregroundStyle(.quaternary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView()
        .frame(width: 600, height: 400)
}
