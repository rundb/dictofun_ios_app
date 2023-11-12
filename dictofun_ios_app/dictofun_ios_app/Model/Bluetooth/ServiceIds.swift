// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2023, Roman Turkin
 */

import Foundation

struct ServiceIds {
    // MARK: - FTS Identifiers
    struct FTS {
        static let service = "a0451001-b822-4820-8782-bd8faf68807b"
        static let controlPointCh = "1002"
        static let fileListCh = "1003"
        static let fileInfoCh = "1004"
        static let fileDataCh = "1005"
        static let fsStatusCh = "1006"
        static let statusCh =  "1007"
        static let fileListNextCh = "1008"
    }
    struct BAS {
        static let service = "0000180F-0000-1000-8000-00805f9b34fb"
        static let batteryLevelCh = "2A19"
    }
    static let pairingWriteCh = "10FE"

}
