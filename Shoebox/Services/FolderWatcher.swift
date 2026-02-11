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

final class FolderWatcher {
    private var stream: FSEventStreamRef?
    private let onChange: () -> Void
    private let debounceInterval: TimeInterval
    private var debounceWork: DispatchWorkItem?

    init(debounceInterval: TimeInterval = 0.5, onChange: @escaping () -> Void) {
        self.debounceInterval = debounceInterval
        self.onChange = onChange
    }

    deinit {
        stop()
    }

    func watch(url: URL) {
        stop()

        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()

        guard let stream = FSEventStreamCreate(
            nil,
            folderWatcherCallback,
            &context,
            [url.path as CFString] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0,
            UInt32(kFSEventStreamCreateFlagUseCFTypes)
        ) else { return }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
    }

    func stop() {
        debounceWork?.cancel()
        debounceWork = nil
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        stream = nil
    }

    fileprivate func handleEvents() {
        debounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.onChange()
        }
        debounceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }
}

private func folderWatcherCallback(
    streamRef: ConstFSEventStreamRef,
    clientCallBackInfo: UnsafeMutableRawPointer?,
    numEvents: Int,
    eventPaths: UnsafeMutableRawPointer,
    eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let info = clientCallBackInfo else { return }
    Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue().handleEvents()
}
