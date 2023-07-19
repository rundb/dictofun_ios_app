//
//  PairingViewController.swift
//  dictofun_ios_app
//
//  Created by Roman on 19.07.23.
//

import UIKit
import CoreBluetooth

class PairingViewController: UIViewController {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var deviceNameLabel: UILabel!
    @IBOutlet weak var deviceIDLabel: UILabel!
    @IBOutlet weak var deviceRSSILabel: UILabel!
    @IBOutlet weak var deviceConnectDisconnectButton: UIButton!
    @IBOutlet weak var devicePairButton: UIButton!
    
    var targetPeripheral: CBPeripheral?
    var bluetoothManager: BluetoothManager?
    
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
            print("targetPeripheral has been nil")
        }
        
        
    }
    
    @IBAction func connectDisconnectButtonPressed(_ sender: UIButton) {
    }
    
    @IBAction func pairButtonPressed(_ sender: UIButton) {
    }
    
}
