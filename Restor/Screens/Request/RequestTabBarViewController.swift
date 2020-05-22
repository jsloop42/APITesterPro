//
//  RequestTabBarViewController.swift
//  Restor
//
//  Created by jsloop on 04/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

extension Notification.Name {
    static let requestVCShouldPresent = Notification.Name("request-vc-should-present")
    static let responseSegmentDidChange = Notification.Name("response-segment-did-change")
    static let editRequestDidTap = Notification.Name("edit-request-did-tap")
    static let viewRequestHistoryDidTap = Notification.Name("view-request-history-did-tap")
}

class RequestTabBarController: UITabBarController, UITabBarControllerDelegate {
    var request: ERequest?
    var segView: UISegmentedControl!
    private let ck = EACloudKit.shared
    private let nc = NotificationCenter.default
    private var selectedTab: Tab = .request
    private var barBtn: UIButton!
    
    enum Tab: Int {
        case request
        case response
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        _ = self.segmentControl()
    }
       
    override func viewDidLoad() {
        Log.debug("request tab bar controller")
        self.addNavigationBarEditButton()
        self.delegate = self
        self.selectedIndex = 1
    }
    
    /// Display Edit button in navigation bar
    func addNavigationBarEditButton() {
        self.barBtn = UIButton(type: .custom)
        self.barBtn.setTitleColor(self.barBtn.tintColor, for: .normal)
        self.barBtn.addTarget(self, action: #selector(self.rightBarButtonDidTap(_:)), for: .touchUpInside)
        self.updateBarButtonText()
    }
    
    func updateBarButtonText() {
        self.barBtn.setTitle(self.selectedTab == .request ? "Edit" : "History", for: .normal)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: self.barBtn)
    }
    
    @objc func rightBarButtonDidTap(_ sender: Any) {
        Log.debug("req-resp right button did tap")
        guard let req = self.request else { return }
        if self.selectedTab == .request {
            self.nc.post(name: .editRequestDidTap, object: self, userInfo: ["request": req])
        } else if self.selectedTab == .response {
            self.nc.post(name: .viewRequestHistoryDidTap, object: self, userInfo: ["request": req])
        }
    }
    
    func segmentControl() -> UISegmentedControl {
        if self.segView != nil { return self.segView }
        self.segView = UISegmentedControl(items: ResponseMode.allCases)
        self.segView.selectedSegmentIndex = self.ck.getValue(key: Const.responseSegmentIndexKey) as? Int ?? ResponseMode.info.rawValue
        self.segView.sizeToFit()
        self.segView.addTarget(self, action: #selector(self.segmentDidChange(_:)), for: .valueChanged)
        return self.segView!
    }
    
    func viewNavbarSegment() {
        self.segView.selectedSegmentIndex = self.ck.getValue(key: Const.responseSegmentIndexKey) as? Int ?? ResponseMode.info.rawValue
        self.navigationItem.titleView = self.segView
    }
    
    func hideNavbarSegment() {
        self.navigationItem.titleView = nil
    }
    
    @objc func segmentDidChange(_ sender: Any) {
        Log.debug("segment did change")
        self.nc.post(name: .responseSegmentDidChange, object: self, userInfo: ["index": self.segView!.selectedSegmentIndex])
    }
    
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        self.selectedTab = Tab(rawValue: tabBarController.selectedIndex) ?? .request
        self.updateBarButtonText()
    }
}
