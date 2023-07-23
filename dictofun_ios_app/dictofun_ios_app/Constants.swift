// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2023, Roman Turkin
 */

struct K {
    static let pairingViewSegueName = "goToPairing"
    static let initialToMenuSegueName = "initialToMenu"
    static let connectionViewSegueName = "connectionViewSegue"
    static let initialToRecordsSegueName = "initialToRecordsView"
    static let recordsToMenuSegue = "recordsToMenuSegue"
    
    struct Pairing {
        static let connectButtonText = "Connect"
        static let disconnectButtonText = "Disconnect"
    }
    
    struct Record {
        static let recordNibName = "RecordCell"
        static let reusableCellName = "RecordReusableCell"
    }
    
    // User Defaults keys
    static let isPairedKey = "isPaired"
}
