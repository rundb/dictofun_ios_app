//
//  MenuViewController.swift
//  dictofun_ios_app
//
//  Created by Roman on 14.07.23.
//

import UIKit
import AVFoundation

class MenuViewController: UIViewController {
    var fts: FileTransferService?

    @IBOutlet weak var bleConnectionStatusLabel: UILabel!
    @IBOutlet weak var ftsStatusLabel: UILabel!
    @IBOutlet weak var ftsTransactionProgressBar: UIProgressView!
    @IBOutlet weak var playbackRecordNameLabel: UILabel!
    @IBOutlet weak var playButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        fts = getFileTransferService()
        bleConnectionStatusLabel.textColor = .black
        ftsStatusLabel.textColor = .black
        playbackRecordNameLabel.textColor = .black
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        getBluetoothManager().uiUpdateDelegate = self
        fts?.uiUpdateDelegate = self
        ftsTransactionProgressBar.isHidden = true
        playbackRecordNameLabel.isHidden = true
        playButton.isHidden = true
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
    
    @IBAction func testFts1ButtonPressed(_ sender: UIButton) {
        print("Fts 1 button pressed: get files' list")
        let filesListResult = fts?.requestFilesList()
        guard filesListResult == nil else {
            print("Files List request has failed")
            return
        }
    }
    @IBAction func testFts2ButtonPressed(_ sender: UIButton) {
        print("Fts 2 button pressed: test file info request")
        let filesIds = fts?.getFileIds()
        if (filesIds?.count ?? 0) > 0 {
            let count = filesIds!.count
            let lastId = filesIds![count - 1]
            let error = fts?.requestFileInfo(with: lastId)
            if error != nil {
                print("FTS file info request has failed")
            }
        }
    }
    
    @IBAction func testFts3ButtonPressed(_ sender: UIButton) {
        print("Fts 3 button pressed: test file data request")
        let filesIds = fts?.getFileIds()
        if (filesIds?.count ?? 0) > 0 {
            let count = filesIds!.count
            let lastId = filesIds![count - 1]
            let error = fts?.requestFileData(with: lastId)
            if error != nil {
                print("FTS file data request has failed")
            }
        }
    }
    @IBAction func playButtonPressed(_ sender: UIButton) {
        NSLog("play button pressed")
        if playbackRecordNameLabel.isHidden {
            NSLog("MenuViewController: record's label is hidden. Are there any records stored?")
            return
        }
        guard let recordUrl = recordsManager.getRecordURL(withFileName: playbackRecordNameLabel.text!) else {
            NSLog("MenuViewController: failed to get record's URL")
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            
            NSLog(recordUrl.relativePath)
            recordsManager.player = try AVAudioPlayer(contentsOf: recordUrl, fileTypeHint: AVFileType.wav.rawValue)
            guard let player = recordsManager.player else {
                NSLog("MenuViewController: failed to get player object")
                return
            }
            let playResult = player.play()
            if !playResult {
                NSLog("Failed to play back the record")
            }
        }
        catch let error {
            NSLog("MenuViewController: playback error \(error.localizedDescription)")
        }
        
    }
}

extension MenuViewController: UIBleStatusUpdateDelegate {
    func didConnectionStatusUpdate(newState state: ConnectionState) {
        bleConnectionStatusLabel.text = "Connection status: \(state == .on ? "connected" : "disconnected")"
    }
}

extension MenuViewController: FtsToUiNotificationDelegate {

    func didReceiveFilesCount(with filesCount: Int) {
        ftsStatusLabel.text = "FTS: DF contains \(filesCount) files"
    }
    
    func didReceiveNextFileSize(with fileName: String, and fileSize: Int) {
        ftsStatusLabel.text = "FTS: Next file \(fileName) is \(fileSize) bytes large"
    }
    
    func didReceiveFileDataChunk(with progressPercentage: Double) {
        if ftsTransactionProgressBar.isHidden {
            ftsTransactionProgressBar.isHidden = false
        }
        ftsTransactionProgressBar.progress = Float(progressPercentage)
    }
    
    func didCompleteFileTransaction(name fileName: String, with duration: Int, and throughput: Int) {
        ftsStatusLabel.text = "FTS: file \(fileName) \nreceived in \(duration) seconds, \n\(throughput)bytes/sec"
        playButton.isHidden = false
        playbackRecordNameLabel.isHidden = false
        playbackRecordNameLabel.text = fileName
    }
    
    
}
