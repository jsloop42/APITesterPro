//
//  RequestCoordinator.swift
//  Restor
//
//  Created by jsloop on 14/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

class RequestCoordinator: EACoordinator {
    let presenter: UINavigationController
    private let nc = NotificationCenter.default
    let request: ERequest
    
    deinit {
        self.nc.removeObserver(self)
    }
    
    init(presenter: UINavigationController, request: ERequest) {
        self.presenter = presenter
        self.request = request
        self.initEvents()
    }
    
    func initEvents() {
        
    }
    
    func start() {
        DispatchQueue.main.async {
            if let vc = UIStoryboard.requestTabBar {
                vc.request = self.request
                self.presenter.pushViewController(vc, animated: true)
            }
        }
    }
}