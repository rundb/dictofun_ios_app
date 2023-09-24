// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2023, Roman Turkin
 */

import UIKit
import AVFoundation

class MenuViewController: UIViewController {
    @IBOutlet weak var bleConnectionStatusLabel: UILabel!
    @IBOutlet weak var ftsStatusLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        bleConnectionStatusLabel.textColor = .black
        ftsStatusLabel.textColor = .black
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        getBluetoothManager().uiUpdateDelegate = self
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        getBluetoothManager().uiUpdateDelegate = nil
    }
    
    @IBAction func menuUnpairButtonPressed(_ sender: UIButton) {
        getBluetoothManager().unpair()
        self.navigationController?.popToRootViewController(animated: true)
    }
    
    @IBAction func deleteAllRecordsButtonPressed(_ sender: UIButton) {
        getAudioFilesManager().removeAllRecords()
        getRecordsManager().deleteAllRecords()
    }
    @IBAction func testDatabaseAccess(_ sender: UIButton) {
        NSLog("REMOVE ME")
    }
    
}

extension MenuViewController: UIBleStatusUpdateDelegate {
    func didConnectionStatusUpdate(newState state: ConnectionState) {
        bleConnectionStatusLabel.text = "Connection status: \(state == .on ? "connected" : "disconnected")"
    }
}
