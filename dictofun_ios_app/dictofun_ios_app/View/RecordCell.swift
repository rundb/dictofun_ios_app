// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2023, Roman Turkin
 */

import UIKit

protocol TableReloadDelegate {
    func reloadTable()
}

class RecordCell: UITableViewCell {

    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var timeOfRecordLabel: UILabel!
    @IBOutlet weak var recordProgressBar: UIProgressView!
    @IBOutlet weak var playbackTimeLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var transcriptLabel: UILabel!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var removeRecordButton: UIButton!
    
    var recordURL: URL?
    let audioPlayer: AudioPlayer = getAudioPlayer()
    
    var tableReloadDelegate: TableReloadDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    @IBAction func playButtonPressed(_ sender: UIButton) {
        guard let url = recordURL else {
            NSLog("play button: url is nil")
            return
        }
        NSLog("Playing record \(url.relativePath)")
        let result = audioPlayer.playRecord(url)
        if result != nil {
            recordProgressBar.isHidden = false
        }
    }
    @IBAction func removeButtonPressed(_ sender: UIButton) {
        getAudioFilesManager().removeRecord(recordURL!)
        // TODO: remove the table cell too after this operation completion
        guard let delegate = tableReloadDelegate else {
            return
        }
        delegate.reloadTable()
    }
    
}
