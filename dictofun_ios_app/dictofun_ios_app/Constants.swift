// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2023, Roman Turkin
 */

struct K {
    static let pairingViewSegueName = "goToPairing"
    static let initialToMenuSegueName = "initialToMenu"
    static let connectionViewSegueName = "connectionViewSegue"
    
    struct Pairing {
        static let connectButtonText = "Connect"
        static let disconnectButtonText = "Disconnect"
    }
    
    // User Defaults keys
    static let isPairedKey = "isPaired"
}
