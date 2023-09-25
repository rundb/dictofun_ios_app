// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2023, Roman Turkin
 */

import Foundation

// This type describes which actions are pending for a particular record
struct FtsJob {
    var fileId: FileId
    var shouldFetchMetadata: Bool
    var shouldFetchData: Bool
    var fileSize: Int
}
