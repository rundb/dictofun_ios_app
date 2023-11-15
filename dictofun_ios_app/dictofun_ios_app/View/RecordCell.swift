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
    @IBOutlet weak var transcriptLabel: UILabel!
    
    var recordURL: URL?
    var recordUUID: UUID?
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
}
