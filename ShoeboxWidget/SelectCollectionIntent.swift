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

import AppIntents
import WidgetKit

enum SlideshowInterval: String, AppEnum {
    case fiveSeconds = "5"
    case tenSeconds = "10"
    case thirtySeconds = "30"
    case oneMinute = "60"
    case fiveMinutes = "300"
    case fifteenMinutes = "900"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Slideshow Interval"

    static var caseDisplayRepresentations: [SlideshowInterval: DisplayRepresentation] = [
        .fiveSeconds: "5 seconds",
        .tenSeconds: "10 seconds",
        .thirtySeconds: "30 seconds",
        .oneMinute: "1 minute",
        .fiveMinutes: "5 minutes",
        .fifteenMinutes: "15 minutes",
    ]

    var seconds: TimeInterval {
        TimeInterval(rawValue)!
    }
}

struct SelectCollectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Collection"
    static var description: IntentDescription = "Choose which photo collection to display."

    @Parameter(title: "Collection")
    var collection: CollectionAppEntity?

    @Parameter(title: "Interval", default: .tenSeconds)
    var interval: SlideshowInterval
}
