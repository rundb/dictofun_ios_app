// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2023, Roman Turkin
 */

import Foundation
import CoreBluetooth

class FileTransferService {
    private var manager: CBCentralManager?
    private var pairingWriteCharacteristic: CBCharacteristic?
    private var ftsCPCharacteristic: CBCharacteristic?
    private var ftsFileListCharacteristic: CBCharacteristic?
    private var ftsFileInfoCharacteristic: CBCharacteristic?
    private var ftsFileDataCharacteristic: CBCharacteristic?
    private var ftsFSStatusCharacteristic: CBCharacteristic?
    private var ftsStatusCharacteristic: CBCharacteristic?
    
}
