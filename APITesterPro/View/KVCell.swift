//
//  KVCell.swift
//  APITesterPro
//
//  Created by Jaseem V V on 23/05/20.
//  Copyright © 2020 Jaseem V V. All rights reserved.
//

import Foundation
import UIKit

/// A cell with two column layout which can be used for displaying key value pair data.
/// Example usage: display response header key value pairs.
class KVCell: UITableViewCell {
    @IBOutlet weak var keyLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var borderView: UIView!
    
    func hideBorder() {
        if self.borderView == nil { return }
        self.borderView.isHidden = true
    }
    
    func showBorder() {
        if self.borderView == nil { return }
        self.borderView.isHidden = false
    }
}
