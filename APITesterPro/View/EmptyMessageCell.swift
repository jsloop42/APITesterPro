//
//  EmptyMessageCell.swift
//  APITesterPro
//
//  Created by Jaseem V V on 04/02/24.
//  Copyright © 2024 Jaseem V V. All rights reserved.
//

import Foundation
import UIKit

class EmptyMessageCell: UITableViewCell {
    let cellReuseIndentifier = TableCellId.workspaceCell.rawValue
    let messageLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .placeholderText
        label.font = App.Font.font17
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.initUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(style: .default, reuseIdentifier: self.cellReuseIndentifier)
        self.initUI()
    }
    
    func initUI() {
        self.addSubview(self.messageLabel)
        NSLayoutConstraint.activate([
            self.messageLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            self.messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            self.messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            self.messageLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }
    
    func updateMessage(_ msg: String) {
        messageLabel.text = msg
    }
}
