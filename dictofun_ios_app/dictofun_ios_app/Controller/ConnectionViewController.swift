//
//  ConnectionViewController.swift
//  dictofun_ios_app
//
//  Created by Roman on 14.07.23.
//

import UIKit
import CoreBluetooth

protocol ScannerDelegate {
    func didDiscoverPeripheral(with peripheral: CBPeripheral)
}

class ConnectionViewController: UIViewController {
    
    @IBOutlet weak var devicesTableView: UITableView!
    
    var bluetoothManager: BluetoothManager?
    
    var discoveredPeripherals: [DiscoveredPeripheral] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        bluetoothManager = getBluetoothManager()
        devicesTableView.dataSource = self
        devicesTableView.delegate = self
        bluetoothManager?.scannerDelegate = self
        
        devicesTableView.register(UINib(nibName: "DiscoveredDeviceCell", bundle: nil), forCellReuseIdentifier: "DiscoveredDeviceReusableCell")
    }
    
    @IBAction func searchButtonPressed(_ sender: UIButton) {
        if let bm = bluetoothManager {
            bm.startScanning()
        }
    }
}

// MARK: - UITableViewDataSource
extension ConnectionViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return discoveredPeripherals.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DiscoveredDeviceReusableCell", for: indexPath) as! DiscoveredDeviceCell
        
        cell.discoveredDeviceNameLabel.text = discoveredPeripherals[indexPath.row].name
        cell.discoveredDeviceIDLabel.text = "\(discoveredPeripherals[indexPath.row].peripheral.identifier)"
        cell.discoveredDeviceRSSILabel.text = "\(discoveredPeripherals[indexPath.row].rssi)"
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension ConnectionViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("row \(indexPath.row) is clicked")
    }
    
}


// MARK: - ScannerDelegate
extension ConnectionViewController: ScannerDelegate {
    func didDiscoverPeripheral(with peripheral: CBPeripheral) {
        discoveredPeripherals.append(DiscoveredPeripheral(with: peripheral))
        devicesTableView.reloadData()
    }
}

