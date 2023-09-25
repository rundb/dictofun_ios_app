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
    @IBOutlet weak var ftsFsStatusLabel: UILabel!
    
    var records: [RecordViewData] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        statusDataLabel.textColor = .black
        ftsStatusLabel.textColor = .black
        ftsFsStatusLabel.textColor = .black
        getBluetoothManager().uiUpdateDelegate = self
        getFtsManager().uiNotificationDelegate = self
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
        getFtsManager().uiNotificationDelegate = nil
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
        cell.dateLabel.textColor = .darkGray
        cell.timeOfRecordLabel.textColor = .black
        cell.playbackTimeLabel.textColor = .darkGray
        cell.durationLabel.textColor = .darkGray
        let r = records[indexPath.row]
        
        if r.durationSeconds != nil {
            cell.durationLabel.text = String(format: "%02d:%02d", r.durationSeconds! / 60, r.durationSeconds! % 60)
        }
        
        let date = r.creationDate
        if date != nil {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MMM/yyyy"
            cell.dateLabel.text = "\(formatter.string(from: date!))"
            formatter.dateFormat = "HH:mm:ss"
            cell.timeOfRecordLabel.text = "\( formatter.string(from: date!) )"
        }
        else {
            cell.dateLabel.text = "--/--/--"
            cell.timeOfRecordLabel.text = "\(r.name)"
        }
        
        if r.url != nil {
            cell.recordURL = r.url
            cell.playButton.isEnabled = true
            cell.removeRecordButton.isEnabled = true
        }
        else {
            cell.playButton.isEnabled = false
            cell.removeRecordButton.isEnabled = false
        }
        if r.progress != 0 && r.progress < 100 {
            cell.recordProgressBar.isHidden = false
            cell.recordProgressBar.progress = Float(r.progress) / 100.0
            NSLog("progress \(r.progress)")
        }
        else {
            cell.recordProgressBar.isHidden = true
            cell.recordProgressBar.trackTintColor = .gray
        }
        // TODO: define project-specific set of colors
        if r.isDownloaded {
            cell.contentView.backgroundColor = UIColor(rgb: 0x83eb86)
        }
        else if r.isSizeKnown {
            cell.contentView.backgroundColor = UIColor(rgb: 0xBBDEFB)
        }
        else {
            cell.contentView.backgroundColor = UIColor(rgb: 0xE3F2FD)
        }
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
        reloadTable()
    }
    
    func didReceiveNextFileSize(with fileName: String, and fileSize: Int) {
        ftsStatusLabel.text = "FTS: found new file \(fileName), \(fileSize) bytes"
        reloadTable()
    }
    
    func didReceiveFileDataChunk(with fileId: FileId, and progressPercentage: Double) {
        ftsStatusLabel.text = "FTS: fetching file, \(String(format: "%0.0f", progressPercentage * 100))%"
        //TODO: find the corresponding cell at this point and update the progress bar cell
        if records.isEmpty {
            return
        }

        for r in records {
            if r.name == fileId.name {
                getRecordsManager().setDownloadProgress(id: fileId, Float(progressPercentage))
                reloadTable()
                return
            }
        }
    }
    
    func didCompleteFileTransaction(name fileName: String, with duration: Int) {
        ftsStatusLabel.text = "FTS: fetched file \(fileName) in \(duration) sec"
        reloadTable()
    }
}

// MARK: - TableReloadDelegate
extension RecordsViewController: TableReloadDelegate {
    func reloadTable() {
        records = recordsManager!.getRecordsList()

        recordsTable.reloadData()
    }
    
    
}
