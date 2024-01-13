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
    @IBOutlet weak var batteryLevelLabel: UILabel!
    
    var records: [RecordViewData] = []
    var selectedTableRow = 0
    
    var recordInDownloadIndexPath: IndexPath?
    var recordsInDownloadCount = 0
    var receivedChunksCounter = 0
    let cellReloadChunksCounter = 15
    
    let maxRecordsAtInitialView = 20
    
    override func viewDidLoad() {
        super.viewDidLoad()
        statusDataLabel.textColor = .black
        ftsStatusLabel.textColor = .black
        ftsFsStatusLabel.textColor = .black
        batteryLevelLabel.textColor = .black
        getBluetoothManager().uiUpdateDelegate = self
        getFtsManager().uiNotificationDelegate = self
        getBluetoothManager().batteryLevelUpdateDelegate = self
        recordsManager = getRecordsManager()
        recordsTable.dataSource = self
        recordsTable.register(UINib(nibName: K.Record.recordNibName, bundle: nil), forCellReuseIdentifier: K.Record.reusableCellName)
        recordsTable.delegate = self
        records = recordsManager!.getRecordsList(with: maxRecordsAtInitialView)
        if getBluetoothManager().isConnected() {
            statusDataLabel.text = "Status: connected"
        }
        else {
            statusDataLabel.text = "Status: disconnected"
        }
        recordsTitleLabel.textColor = .black
        
        recordsTitleLabel.isHidden = true
        ftsFsStatusLabel.isHidden = true
        ftsStatusLabel.isHidden = true
        statusDataLabel.isHidden = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        getBluetoothManager().uiUpdateDelegate = nil
        getFtsManager().uiNotificationDelegate = nil
    }
    
    @IBAction func menuButtonPressed(_ sender: UIButton) {
        self.performSegue(withIdentifier: K.recordsToMenuSegue, sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == K.recordsToDetailsSegue {
            let destinationVC = segue.destination as! RecordDetailsViewController
            // URL modification is required (FIXME: it should be implemented properly)
            let url = records[selectedTableRow].url!
            let actualUrl = getAudioFilesManager().getRecordURL(withFileName: url.lastPathComponent)
            destinationVC.recordViewData = records[selectedTableRow]
            destinationVC.recordViewData?.url = actualUrl
            destinationVC.recordsTableReloadDelegate = self
        }
    }
}

// MARK: BASBatteryLevelUpdated
extension RecordsViewController: BASBatteryLevelUpdated {
    func didUpdateBatteryLevel(with level: Int) {
        if level > 10 {
            batteryLevelLabel.isHidden = false
            batteryLevelLabel.text = "Battery: \(level)%"
        }
        else {
            batteryLevelLabel.isHidden = true
        }
    }
}

// MARK: - UITableViewDelegate
extension RecordsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // open a corresponding segue
        selectedTableRow = indexPath.row
        if records[selectedTableRow].isDownloaded {
            self.performSegue(withIdentifier: K.recordsToDetailsSegue, sender: self)
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        NSLog("swiping call")
        return nil
    }
    
}


// MARK: - UITableViewDataSource
extension RecordsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        records = recordsManager!.getRecordsList(with: maxRecordsAtInitialView)
        recordsInDownloadCount = 0
        recordInDownloadIndexPath = nil
        return records.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: K.Record.reusableCellName, for: indexPath) as! RecordCell
        cell.dateLabel.textColor = .darkGray
        cell.timeOfRecordLabel.textColor = .black
        let r = records[indexPath.row]
        
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
        
        cell.recordUUID = r.uuid
        
        if r.url != nil {
            cell.recordURL = r.url
        }
        else {
        }
        if r.progress != 0 && r.progress < 100 {
            cell.recordProgressBar.isHidden = false
            cell.recordProgressBar.progress = Float(r.progress) / 100.0
            recordInDownloadIndexPath = indexPath;
            recordsInDownloadCount += 1
            if recordsInDownloadCount > 1 {
                NSLog("error: more than 1 download in progress")
                recordsInDownloadCount = 0
                recordInDownloadIndexPath = nil
            }
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
        if r.transcription != nil {
            cell.transcriptLabel.text = r.transcription
            cell.transcriptLabel.isHidden = false
        }
        else {
            cell.transcriptLabel.isHidden = true
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
        if records.isEmpty {
            return
        }

        for r in records {
            if r.name == fileId.name {
                getRecordsManager().setDownloadProgress(id: fileId, Float(progressPercentage))
                if recordInDownloadIndexPath != nil {
                    receivedChunksCounter += 1
                    DispatchQueue.main.async {
                        self.ftsStatusLabel.text = "FTS: fetching file, \(String(format: "%0.0f", progressPercentage * 100))%"
                    }
                    if receivedChunksCounter % cellReloadChunksCounter == 0 {
                        DispatchQueue.main.async {
                            if UIApplication.shared.applicationState == .active {
                                self.recordsTable.reloadRows(at: [self.recordInDownloadIndexPath!], with: .automatic)
                            }
                        }
                    }
                }
                else {
                    reloadTable()
                }
                return
            }
        }
    }
    
    func didCompleteFileTransaction(name fileName: String, with duration: Int) {
        ftsStatusLabel.text = "FTS: fetched file \(fileName) in \(duration) sec"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
            if UIApplication.shared.applicationState == .active {
                self.recordsTable.reloadData()
            }
        })
        recordInDownloadIndexPath = nil
        recordsInDownloadCount = 0
    }
}

// MARK: - TableReloadDelegate
extension RecordsViewController: TableReloadDelegate {
    func reloadTable() {
        records = recordsManager!.getRecordsList(with: maxRecordsAtInitialView)
        DispatchQueue.main.async {
            if UIApplication.shared.applicationState == .active {
                self.recordsTable.reloadData()
            }
        }
    }
    
    
}
