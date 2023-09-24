//
//  RecordCell.swift
//  dictofun_ios_app
//
//  Created by Roman on 23.07.23.
//

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
            return
        }
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
