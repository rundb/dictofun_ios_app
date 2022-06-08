// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2022, Roman Turkin
 */

import Foundation

extension Bool {
    var int: Int { self ? 1 : 0 }
}

extension Data {
    var hex: String { map{ String(format: "%02x", $0) }.joined() }
}
