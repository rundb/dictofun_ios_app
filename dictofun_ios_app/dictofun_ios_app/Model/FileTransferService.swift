import Foundation
import CoreBluetooth

protocol CharNotificationDelegate {
    func didCharNotify(with char: CBUUID, and data: Data?, error: Error?)
}

/**
    This class implements all functions needed for file transfer service to operate, according to FTS specification:
     - get files' list from the device
     - get information about a particular file
     - download the file from the device
 */
class FileTransferService {
    var bluetoothManager: BluetoothManager
    
    init(with bluetoothManager: BluetoothManager) {
        self.bluetoothManager = bluetoothManager
    }
    
    func getFilesList() -> Error? {
        return nil
    }
    
}
