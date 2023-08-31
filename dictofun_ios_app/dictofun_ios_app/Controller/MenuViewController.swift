// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2023, Roman Turkin
 */

import UIKit
import AVFoundation

class MenuViewController: UIViewController {
    var fts: FileTransferService?

    @IBOutlet weak var bleConnectionStatusLabel: UILabel!
    @IBOutlet weak var ftsStatusLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        fts = getFileTransferService()
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
        fts?.uiUpdateDelegate = nil
    }
    
    @IBAction func menuUnpairButtonPressed(_ sender: UIButton) {
        getBluetoothManager().unpair()
        self.navigationController?.popToRootViewController(animated: true)
    }
    
    @IBAction func deleteAllRecordsButtonPressed(_ sender: UIButton) {
        getRecordsManager().removeAllRecords()
    }
    @IBAction func testDatabaseAccess(_ sender: UIButton) {
        let context  = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        let newId = UUID()
        let recordId = RecordId(context: context)
        let recordMetaData = MetaData(context: context)
        recordId.id = newId
        
        recordMetaData.id = newId
        recordMetaData.name = "0011223344556677"
        
        
        NSLog("record id: \(recordId)")
        NSLog("record metadata: \(recordMetaData)")
        
        
    }
    
}

extension MenuViewController: UIBleStatusUpdateDelegate {
    func didConnectionStatusUpdate(newState state: ConnectionState) {
        bleConnectionStatusLabel.text = "Connection status: \(state == .on ? "connected" : "disconnected")"
    }
}
