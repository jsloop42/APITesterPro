//
//  APITesterProNavigationController.swift
//  API Tester Pro
//
//  Created by jsloop on 29/10/23.
//  Copyright © 2023 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

/// Ability to intercept back button tap to determine if the page should be changed.
class APITesterProNavigationController: UINavigationController {
    weak var navDelegate: APITesterProTableViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    /// This method is invoked when a view controller is going to be removed from the navigation stack. Since this is a sub class we can decide if we want to call the pop method of the navigation controller or not based on our criteria.
    /// Here we check if the `navDelegate` is set. If so we call its `shouldPopOnBackButton` and invoked pop accordingly.
    override func popViewController(animated: Bool) -> UIViewController? {
        if !(self.navDelegate?.shouldPopOnBackButton() ?? true) { return nil }
        return super.popViewController(animated: animated)
    }
}
