// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2023, Roman Turkin
 */

import UIKit

class RecordsViewController: UIViewController {
    
    var recordsManager: RecordsManager?
    
    @IBOutlet weak var recordsTable: UITableView!
    @IBOutlet weak var statusDataLabel: UILabel!
    @IBOutlet weak var ftsStatusLabel: UILabel!
    @IBOutlet weak var recordsTitleLabel: UILabel!
    
    var records: [Record] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        statusDataLabel.textColor = .black
        ftsStatusLabel.textColor = .black
        getBluetoothManager().uiUpdateDelegate = self
        getFileTransferService().uiUpdateDelegate = self
        recordsManager = getRecordsManager()
        recordsTable.dataSource = self
        recordsTable.register(UINib(nibName: K.Record.recordNibName, bundle: nil), forCellReuseIdentifier: K.Record.reusableCellName)
        records = recordsManager!.getRecordsList()
        if getBluetoothManager().isConnected() {
            statusDataLabel.text = "Status: connected"
        }
        else {
            statusDataLabel.text = "Status: disconnected"
        }
        recordsTitleLabel.textColor = .black
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        getBluetoothManager().uiUpdateDelegate = nil
        getFileTransferService().uiUpdateDelegate = nil
    }
    
    @IBAction func menuButtonPressed(_ sender: UIButton) {
        self.performSegue(withIdentifier: K.recordsToMenuSegue, sender: self)
    }
}

// MARK: - UITableViewDataSource
extension RecordsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        records = recordsManager!.getRecordsList()
        return records.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: K.Record.reusableCellName, for: indexPath) as! RecordCell
        cell.recordDurationLabel.textColor = .black
        cell.recordNameLabel.textColor = .black
        let r = records[indexPath.row]
        cell.recordDurationLabel.text = String(format: "%02d:%02d", r.durationSeconds / 60, r.durationSeconds % 60)
        
        cell.recordNameLabel.text = "\( RecordsManager.getReadableFileName(with: r.name) )"
        cell.recordURL = r.url
        cell.recordProgressBar.isHidden = true
        cell.recordProgressBar.trackTintColor = .gray
        cell.tableReloadDelegate = self
        return cell
    }
}

// MARK: - UIBleStatusUpdateDelegate
extension RecordsViewController: UIBleStatusUpdateDelegate {
    func didConnectionStatusUpdate(newState state: ConnectionState) {
        statusDataLabel.text =  "State:\((state == .off) ? "disconnected" : "connected")"
    }
}

// MARK: - FtsToUiNotificationDelegate
extension RecordsViewController: FtsToUiNotificationDelegate {
    func didReceiveFilesCount(with filesCount: Int) {
        
    }
    
    func didReceiveNextFileSize(with fileName: String, and fileSize: Int) {
        ftsStatusLabel.text = "FTS: found new file \(fileName), \(fileSize) bytes"
    }
    
    func didReceiveFileDataChunk(with progressPercentage: Double) {
        ftsStatusLabel.text = "FTS: fetching file, \(String(format: "%0.0f", progressPercentage * 100))%"
    }
    
    func didCompleteFileTransaction(name fileName: String, with duration: Int, and throughput: Int) {
        ftsStatusLabel.text = "FTS: fetched file \(fileName) in \(duration) sec,\n throughput: \(throughput) bytes/sec"
        recordsTable.reloadData()
    }
}

// MARK: - TableReloadDelegate
extension RecordsViewController: TableReloadDelegate {
    func reloadTable() {
        recordsTable.reloadData()
    }
    
    
}
