//
//  APITesterProViewController.swift
//  APITesterPro
//
//  Created by Jaseem V V on 14/05/20.
//  Copyright © 2020 Jaseem V V. All rights reserved.
//

import Foundation
import UIKit

class APITesterProViewController: UIViewController {
    fileprivate let nc = NotificationCenter.default
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    deinit {
        Log.debug("deinit api tester pro view controller")
    }
    
    func bootstrap() {
        
    }
    
    /// Override this method to determine if the view controller should be popped when user taps the navigation bar back button or provide some call to action.
    override func shouldPopOnBackButton() -> Bool {
        return true
    }
    
    override func willMove(toParent parent: UIViewController?) {
        if parent == nil { return }
        super.willMove(toParent: parent)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Log.debug("is navigated back - \(self.className) - \(self.isNavigatedBack)")
        if self.isNavigatedBack { self.nc.post(name: NSNotification.Name("did-navigate-back-to-\(self.className)"), object: self) }
    }
}
