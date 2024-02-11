//
//  EACopiableLabel.swift
//  APITesterPro
//
//  Created by Jaseem V V on 11.02.2024.
//  Copyright © 2024 Jaseem V V. All rights reserved.
//

import Foundation
import UIKit

/// A UILabel whose text can be copied. Long pressing on the label will show a copy menu which on tap will copy the label text to clipboard.
class EACopiableLabel: UILabel {
    override public var canBecomeFirstResponder: Bool {
        get {
            return true
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.initUI()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.initUI()
    }

    func initUI() {
        self.isUserInteractionEnabled = true
        self.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(self.showCopyMenu(sender:))))
    }

    override func copy(_ sender: Any?) {
        UIPasteboard.general.string = self.text
        UIMenuController.shared.hideMenu()
    }

    @objc func showCopyMenu(sender: Any?) {
        self.becomeFirstResponder()
        let menu = UIMenuController.shared
        if !menu.isMenuVisible {
            menu.showMenu(from: self, rect: self.bounds)
        }
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return (action == #selector(self.copy(_:)))
    }
}
