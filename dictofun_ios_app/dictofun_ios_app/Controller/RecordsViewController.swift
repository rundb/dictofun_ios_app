// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2023, Roman Turkin
 */

import UIKit

class RecordsViewController: UIViewController {
    
    var audioFilesManager: AudioFilesManager?
    
    @IBOutlet weak var recordsTable: UITableView!
    @IBOutlet weak var statusDataLabel: UILabel!
    @IBOutlet weak var ftsStatusLabel: UILabel!
    @IBOutlet weak var recordsTitleLabel: UILabel!
    @IBOutlet weak var ftsFsStatusLabel: UILabel!
    
    var records: [Record] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        statusDataLabel.textColor = .black
        ftsStatusLabel.textColor = .black
        ftsFsStatusLabel.textColor = .black
        getBluetoothManager().uiUpdateDelegate = self
        getFtsManager().uiNotificationDelegate = self
        audioFilesManager = getAudioFilesManager()
        recordsTable.dataSource = self
        recordsTable.register(UINib(nibName: K.Record.recordNibName, bundle: nil), forCellReuseIdentifier: K.Record.reusableCellName)
        records = audioFilesManager!.getRecordsList(excludeEmpty: true)
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
        getFtsManager().uiNotificationDelegate = nil
    }
    
    @IBAction func menuButtonPressed(_ sender: UIButton) {
        self.performSegue(withIdentifier: K.recordsToMenuSegue, sender: self)
    }
}

// MARK: - UITableViewDataSource
extension RecordsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        records = audioFilesManager!.getRecordsList(excludeEmpty: true)
        return records.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: K.Record.reusableCellName, for: indexPath) as! RecordCell
        cell.dateLabel.textColor = .darkGray
        cell.timeOfRecordLabel.textColor = .black
        cell.playbackTimeLabel.textColor = .darkGray
        cell.durationLabel.textColor = .darkGray
        let r = records[indexPath.row]
        
        cell.durationLabel.text = String(format: "%02d:%02d", r.durationSeconds / 60, r.durationSeconds % 60)
        
        cell.dateLabel.text = "\( AudioFilesManager.getReadableRecordDate(with: r.name) )"
        cell.timeOfRecordLabel.text = "\( AudioFilesManager.getReadableRecordTime(with: r.name) )"
        
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
    func didReceiveFileSystemState(count filesCount: Int, occupied occupiedMemory: Int, free freeMemory: Int) {
        ftsFsStatusLabel.text = "FS Stat: count=\(filesCount), occupied=\(occupiedMemory/1024)Kb, free=\(freeMemory/1024)"
    }
    
    func didReceiveFilesCount(with filesCount: Int) {
        ftsFsStatusLabel.text = "Files count = \(filesCount)"
    }
    
    func didReceiveNextFileSize(with fileName: String, and fileSize: Int) {
        ftsStatusLabel.text = "FTS: found new file \(fileName), \(fileSize) bytes"
    }
    
    func didReceiveFileDataChunk(with progressPercentage: Double) {
        ftsStatusLabel.text = "FTS: fetching file, \(String(format: "%0.0f", progressPercentage * 100))%"
    }
    
    func didCompleteFileTransaction(name fileName: String, with duration: Int) {
        ftsStatusLabel.text = "FTS: fetched file \(fileName) in \(duration) sec"
        recordsTable.reloadData()
    }
}

// MARK: - TableReloadDelegate
extension RecordsViewController: TableReloadDelegate {
    func reloadTable() {
        recordsTable.reloadData()
    }
    
    
}
