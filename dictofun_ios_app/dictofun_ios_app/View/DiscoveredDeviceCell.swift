// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2023, Roman Turkin
 */

import UIKit

class DiscoveredDeviceCell: UITableViewCell {

    @IBOutlet weak var discoveredDeviceEntryView: UIView!
    
    @IBOutlet weak var discoveredDeviceNameLabel: UILabel!
    @IBOutlet weak var discoveredDeviceIDLabel: UILabel!
    @IBOutlet weak var discoveredDeviceRSSILabel: UILabel!
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
}
