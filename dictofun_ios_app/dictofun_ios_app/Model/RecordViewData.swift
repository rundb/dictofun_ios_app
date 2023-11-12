// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2023, Roman Turkin
 */

import Foundation

struct RecordViewData {
    let url: URL?
    let uuid: UUID?
    let creationDate: Date?
    let durationSeconds: Int?
    let isDownloaded: Bool
    let isSizeKnown: Bool
    let name: String
    var progress: Int
    let transcription: String?
}
