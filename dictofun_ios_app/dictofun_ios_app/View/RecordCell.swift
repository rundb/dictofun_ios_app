//
//  RecordCell.swift
//  dictofun_ios_app
//
//  Created by Roman on 23.07.23.
//

import UIKit

class RecordCell: UITableViewCell {

    @IBOutlet weak var recordNameLabel: UILabel!
    @IBOutlet weak var recordDurationLabel: UILabel!
    @IBOutlet weak var recordProgressBar: UIProgressView!
    
    var recordURL: URL?
    
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
        let result = getRecordsManager().playRecord(url)
        if result != nil {
            recordProgressBar.isHidden = false
        }
    }
    @IBAction func removeButtonPressed(_ sender: UIButton) {
        getRecordsManager().removeRecord(recordURL!)
        // TODO: remove the table cell too after this operation completion
    }
    
}
