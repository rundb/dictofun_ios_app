// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2023, Roman Turkin
 */

import UIKit
import CoreBluetooth

protocol ConnectDelegate {
    func didConnectToPeripheral(error: Error?)
    func didDisconnectFromPeripheral()
}

protocol PairDelegate {
    func didPairWithPeripheral(error: Error?)
}

class PairingViewController: UIViewController {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var deviceNameLabel: UILabel!
    @IBOutlet weak var deviceIDLabel: UILabel!
    @IBOutlet weak var deviceRSSILabel: UILabel!
    @IBOutlet weak var deviceConnectDisconnectButton: UIButton!
    @IBOutlet weak var devicePairButton: UIButton!
    
    var targetPeripheral: CBPeripheral?
    var bluetoothManager: BluetoothManager?
    
    func setState(button: UIButton, active state: Bool) {
        button.isEnabled = state
        button.backgroundColor = (state) ? .red : .gray
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        bluetoothManager = getBluetoothManager()
        
        if let p = targetPeripheral {
            deviceNameLabel.text = targetPeripheral?.name
            deviceIDLabel.text = "\(p.identifier)"
            deviceRSSILabel.text = "\(p.rssi?.intValue ?? 0)"
            
            titleLabel.textColor = .black
            deviceNameLabel.textColor = .black
            deviceIDLabel.textColor = .black
            deviceRSSILabel.textColor = .black
        }
        else {
            NSLog("targetPeripheral has been nil")
            assert(false)
        }
        
        setState(button: devicePairButton, active: false)
        deviceConnectDisconnectButton.titleLabel?.text = K.Pairing.connectButtonText
    }
    
    @IBAction func connectDisconnectButtonPressed(_ sender: UIButton) {
        if let bm = bluetoothManager, let p = targetPeripheral {
            bm.connectDelegate = self
            if bm.isConnected() {
                bm.cancelPeripheralConnection()
            }
            else {
                bm.connectPeripheral(peripheral: p)
            }
        }
        else {
            NSLog("PairingView Error: bluetoothManager is not initialized")
            assert(false)
        }
    }
    
    @IBAction func pairButtonPressed(_ sender: UIButton) {
        bluetoothManager?.pairDelegate = self
        if let p = targetPeripheral {
            let pairImmediateResult = bluetoothManager?.pairWithPeripheral(p)
            if pairImmediateResult != nil {
                NSLog("PairingView: pairing has failed. Nothing is going to happen")
            }
        }
    }
    
}

extension PairingViewController : ConnectDelegate {
    func didConnectToPeripheral(error: Error?) {
        if let e = error {
            NSLog("PairingView: Peripheral has failed to connect, error: \(e.localizedDescription)")
            return
        }
        deviceConnectDisconnectButton.titleLabel?.text = K.Pairing.disconnectButtonText
        
        setState(button: devicePairButton, active: true)
    }
    
    func didDisconnectFromPeripheral() {
        deviceConnectDisconnectButton.titleLabel?.text = K.Pairing.connectButtonText
        setState(button: devicePairButton, active: false)
    }
}

extension PairingViewController : PairDelegate {
    func didPairWithPeripheral(error: Error?) {
        guard error == nil else {
            NSLog("Pairing view: pairing error detected, \(error!.localizedDescription)")
            return
        }
        // At this point we are done and can close all views back to initial one
        NSLog("Pairing view: did pair with peripheral. Rolling back to initial view")
        self.navigationController?.popToRootViewController(animated: true)
    }
}
