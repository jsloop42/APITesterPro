//
//  ResponseTableViewController.swift
//  Restor
//
//  Created by jsloop on 04/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit
import WebKit

// MARK: - ResponseInfoCell

class ResponseInfoCell: UITableViewCell {
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var urlLabel: UILabel!
    @IBOutlet weak var statusCodeView: UIView!
    @IBOutlet weak var statusCodeLabel: UILabel!
    @IBOutlet weak var statusMessageLabel: UILabel!
    @IBOutlet weak var statusSizeLabel: UILabel!
    @IBOutlet weak var infoView: UIView!
    var mode: ResponseMode = .preview
    var data: ResponseData?
    private lazy var app = { App.shared }()
    private lazy var utils = { EAUtils.shared }()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.updateUI()
    }
    
    func updateUI() {
        guard let data = self.data, let req = data.request else { return }
        self.nameLabel.text = req.name
        self.urlLabel.text = "\(data.method) \(data.url)"
        
        //self.nameLabel.text = "Get the list of all users filtered by active sorted by first name grouped by location joined by demographics segemented by geolocation"
        //self.urlLabel.text = "https://piperway.com/rest/list/user/sort/filter/group?param=search&name=first"
        //self.nameLabel.text = "Get list of all users"
        //self.urlLabel.text = "https://piperway.com/test/list/user"
        
        var color: UIColor!
        if data.statusCode > 0 {
            self.statusCodeLabel.text = "\(data.statusCode)"
            self.statusMessageLabel.text = HTTPStatusCode(rawValue: data.statusCode)?.toString() ?? ""
            if data.statusCode == 200 {
                self.statusMessageLabel.textAlignment = .center
            } else {
                self.statusMessageLabel.textAlignment = .right
            }
            var is200 = false
            if (200..<299) ~= data.statusCode {
                color = UIColor(named: "http-status-200")
                is200 = true
            } else if (300..<399) ~= data.statusCode {
                color = UIColor(named: "http-status-300")
            } else if (400..<500) ~= data.statusCode {
                color = UIColor(named: "http-status-400")
            } else if (500..<600) ~= data.statusCode {
                color = UIColor(named: "http-status-500")
            }
            self.statusCodeView.backgroundColor = color
            self.statusMessageLabel.textColor = is200 ? UIColor(named: "http-status-text-200") : color
        } else if data.statusCode == -1 {  // error
            self.statusCodeView.backgroundColor = UIColor(named: "http-status-error")
            self.statusMessageLabel.textColor = UIColor(named: "http-status-error")
            self.statusCodeLabel.text = "Error"
            self.statusMessageLabel.text = ""
        } else {
            self.statusCodeView.backgroundColor = UIColor(named: "http-status-none")
            self.statusMessageLabel.textColor = UIColor(named: "help-text-fg")
        }
        let ts = data.connectionInfo.elapsed > 0 ? self.app.formatElapsed(data.connectionInfo.elapsed) : ""
        if data.responseSize > 0 {
            self.statusSizeLabel.text = "\(!ts.isEmpty ? "\(ts), " : "")\(self.utils.bytesToReadable(data.responseSize.toInt64()))"
        } else {
            self.statusSizeLabel.text = "\(ts)"
        }
    }
    
    func displayNoResponse() {
        UIView.animate(withDuration: 0.3) {
//            self.topBorderView.isHidden = true
//            self.infoView.isHidden = true
//            self.bottomBorderView.isHidden = true
        }
    }
}

enum ResponseKVTableType: String {
    case header = "response-header-table-view"
    case cookies = "response-cookies-table-view"
    case details = "response-details-table-view"
}

// MARK: - ResponseKVCell

class ResponseKVCell: UITableViewCell, UITableViewDataSource, UITableViewDelegate {
    //@IBOutlet weak var tableView: EADynamicSizeTableView!
     var tableView: EADynamicSizeTableView!
    var isInit = false
    var data: ResponseData?
    let cellId = "twoColumnCell"
    var tableType: ResponseKVTableType = .header
    var headers: [String: String] = [:]
    var headerKeys: [String] = []
    var heightMap: [Int: CGFloat] = [:] // [Row: Height]
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.bootstrap()
    }
    
    func bootstrap() {
        if !self.isInit {
            UIView.animate(withDuration: 0.3) { self.initUI() }
            self.isInit = true
        }
    }
    
    func initUI() {
        self.tableView = EADynamicSizeTableView(frame: self.contentView.frame, style: .plain)
        self.tableView.tableViewId = self.tableType.rawValue
        self.tableView.register(UINib(nibName: "KVCell", bundle: nil), forCellReuseIdentifier: "kvCell")
        self.tableView.drawBorders = false
        self.tableView.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(self.tableView)
        NSLayoutConstraint.activate([
            self.tableView.topAnchor.constraint(equalTo: self.contentView.topAnchor),
            self.tableView.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor),
            self.tableView.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor),
            self.tableView.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor)
        ])
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.separatorStyle = .none
    }
    
    func updateUI() {
        self.updateData()
        self.tableView.reloadData()
    }
    
    func updateData() {
        guard let data = self.data else { return }
        self.headers = data.getResponseHeaders()
        self.headerKeys = data.getResponseHeaderKeys()
    }

    // MARK: - Table view
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch self.tableType {
        case .header:
            return self.headerKeys.count
        case .cookies:
            return self.data?.cookies.count ?? 0
        case .details:
            return 12
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "kvCell", for: indexPath) as! KVCell
        let row = indexPath.row
        if self.tableType == .header {
            let key = self.headerKeys[row]
            cell.keyLabel.text = key
            //cell.keyLabel.text = "A machine is only as good as the man who programs it. A machine is only as good as the man who programs it"
            cell.valueLabel.text = self.headers[key]
            (row == self.headerKeys.count - 1) ? cell.hideBottomBorder() : cell.displayBottomBorder()
        } else if self.tableType == .cookies {
            if let data = self.data {
                let cookie = data.cookies[row]
                cell.keyLabel.text = cookie.name
                cell.valueLabel.text = cookie.value
                (row == data.cookies.count - 1) ? cell.hideBottomBorder() : cell.displayBottomBorder()
            }
        } else if self.tableType == .details {
            
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let row = indexPath.row
        var key = ""
        var val = ""
        if self.tableType == .header {
            key = self.headerKeys[row]
            val = self.headers[key] ?? ""
        } else if self.tableType == .cookies {
            if let cookie = self.data?.cookies[row] {
                key = cookie.name
                val = cookie.value
            }
        }
        //key = "A machine is only as good as the man who programs it. A machine is only as good as the man who programs it"
        let text = val.count >= key.count ? val : key
        Log.debug("text: \(text)")
        let width = tableView.frame.width / 2 - 32
        let h = max(UI.getTextHeight(text, width: width, font: UIFont.systemFont(ofSize: 14)) + 28, 55)
        Log.debug("header cell height h: \(h)")
        self.tableView.setHeight(h, forRowAt: indexPath)
        return h
    }
}

enum ResponseMode: Int {
    case info
    case raw
    case preview
    
    static var allCases = ["Info", "Raw", "Preview"]
}

// MARK: - ResponseTableViewController

class ResponseTableViewController: RestorTableViewController {
    private let nc = NotificationCenter.default
    private lazy var ck = { EACloudKit.shared }()
    private lazy var localdb = { CoreDataService.shared }()
    private lazy var utils = { EAUtils.shared }()
    private lazy var tabbarController = { self.tabBarController as! RequestTabBarController }()
    var mode: ResponseMode = .info
    @IBOutlet weak var infoCell: ResponseInfoCell!
    @IBOutlet weak var headersViewCell: ResponseKVCell! {
        didSet { self.headersViewCell.tableType = .header }
    }
    @IBOutlet weak var cookiesViewCell: ResponseKVCell! {
        didSet { self.cookiesViewCell.tableType = .cookies }
    }
    @IBOutlet weak var detailsViewCell: ResponseKVCell! {
        didSet { self.detailsViewCell.tableType = .details }
    }
    @IBOutlet weak var helpCell: ResponseInfoCell!
    private var headerCellHeight: CGFloat = 0.0
    private var cookieCellHeight: CGFloat = 0.0
    private var detailsCellHeight: CGFloat = 0.0
    private var previousHeaderCellHeight: CGFloat = 0.0
    private var previousCookieCellHeight: CGFloat = 0.0
    private var previousDetailsCellHeight: CGFloat = 0.0
    var data: ResponseData?
    
    enum InfoCellId: Int {
        case spacerBeforeInfoCell
        case infoCell
        case headerTitleCell
        case headersViewCell
        case cookiesTitleCell
        case cookiesViewCell
        case detailsTitleCell
        case detailsViewCell
        case helpCell
    }
    
    deinit {
        self.nc.removeObserver(self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.initData()
        self.updateUI()
        self.tableView.reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Log.debug("response vc did load")
        self.initUI()
        self.initEvents()
    }
    
    func initData() {
        if self.data == nil {
            self.data = self.tabbarController.responseData
            if self.data == nil, let req = self.tabbarController.request {
                if let history = self.localdb.getLatestHistory(reqId: req.getId(), includeMarkForDelete: nil, ctx: self.localdb.mainMOC) {
                    self.data = ResponseData(history: history)
                    self.data?.history = history
                    self.data?.request = req
                }
            }
        }
        if self.data == nil {
            self.data = tabbarController.responseData
            self.data?.request = self.tabbarController.request
            if self.data != nil, self.data!.cookiesData != nil, self.data!.cookies.isEmpty {
                self.data!.updateCookies()
            }
        }
        Log.debug("response data: \(String(describing: self.data))")
        // info cell
        self.infoCell.data = self.data
        // headers cell
        self.headersViewCell.tableType = .header
        self.headersViewCell.data = self.data
        // cookies cell
        self.cookiesViewCell.tableType = .cookies
        self.cookiesViewCell.data = self.data
        // details cell
        self.detailsViewCell.tableType = .details
        self.detailsViewCell.data = self.data
    }
    
    func initUI() {
        self.mode = ResponseMode(rawValue: self.tabbarController.segView.selectedSegmentIndex) ?? .info
        self.tabbarController.viewNavbarSegment()
    }
    
    func initEvents() {
        self.nc.addObserver(self, selector: #selector(self.segmentDidChange(_:)), name: .responseSegmentDidChange, object: nil)
        self.nc.addObserver(self, selector: #selector(self.viewRequestHistoryDidTap(_:)), name: .viewRequestHistoryDidTap, object: nil)
        self.nc.addObserver(self, selector: #selector(self.responseDidReceive(_:)), name: .responseDidReceive, object: nil)
        self.nc.addObserver(self, selector: #selector(self.dynamicSizeTableViewHeightDidChange(_:)), name: .dynamicSizeTableViewHeightDidChange, object: nil)
    }
    
    func updateUI() {
        Log.debug("update UI")
        if self.data == nil { return }
        if self.mode == .info {
            self.infoCell.updateUI()
            self.headersViewCell.updateUI()
            self.cookiesViewCell.updateUI()
            self.detailsViewCell.updateUI()
        }
    }
    
    /// Get the dynamic height of the inner table view
    func setHeight(_ height: CGFloat, type: ResponseKVTableType) {
        if type == .header {
            self.headerCellHeight = height
            // Once the height changes, reload the outer table view. Also prevents continuous reloading of the table view.
            if self.headerCellHeight != self.previousHeaderCellHeight {
                self.previousHeaderCellHeight = self.headerCellHeight
            }
        } else if type == .cookies {
            self.cookieCellHeight = height
            if self.cookieCellHeight != self.previousCookieCellHeight {
                self.previousCookieCellHeight = self.cookieCellHeight
            }
        } else if type == .details {
            self.detailsCellHeight = height
            if self.detailsCellHeight != self.previousDetailsCellHeight {
                self.previousDetailsCellHeight = self.detailsCellHeight
            }
        }
        self.tableView.reloadData()
    }
    
    @objc func dynamicSizeTableViewHeightDidChange(_ notif: Notification) {
        Log.debug("dynamic size table view height did change notification")
        if let info = notif.userInfo as? [String: Any], let tableViewId = info["tableViewId"] as? String, let type = ResponseKVTableType(rawValue: tableViewId),
            let height = info["height"] as? CGFloat {
            switch type {
            case .header:
                self.headerCellHeight = height
                self.headersViewCell.tableView.shouldReload = false
                self.tableView.reloadData()
                self.headersViewCell.tableView.shouldReload = true
            case .cookies:
                self.cookieCellHeight = height
                self.cookiesViewCell.tableView.shouldReload = false
                self.tableView.reloadData()
                self.cookiesViewCell.tableView.shouldReload = true
            case .details:
                self.detailsCellHeight = height
                self.detailsViewCell.tableView.shouldReload = false
                self.tableView.reloadData()
                self.detailsViewCell.tableView.shouldReload = true
            }
        }
    }
    
    @objc func segmentDidChange(_ notif: Notification) {
        Log.debug("segment did change notif")
        if let info = notif.userInfo, let idx = info["index"] as? Int {
            self.ck.saveValue(key: Const.responseSegmentIndexKey, value: idx)
            self.mode = ResponseMode(rawValue: idx) ?? .info
            Log.debug("response mode changed: \(self.mode)")
            self.initData()
            self.updateUI()
            self.tableView.reloadData()
        }
    }
    
    @objc func viewRequestHistoryDidTap(_ notif: Notification) {
        Log.debug("view request history did tap")
        guard let info = notif.userInfo, let req = info["request"] as? ERequest, let data = self.data, req.getId() == data.request?.getId() else { return }
        // TODO: display history page
    }
    
    @objc func responseDidReceive(_ notif: Notification) {
        Log.debug("response did receieve")
        if let info = notif.userInfo as? [String: Any], let histId = info["historyId"] as? String {
            DispatchQueue.main.async {
                if let history = self.localdb.getHistory(id: histId, ctx: self.localdb.mainMOC) {
                    self.data = ResponseData(history: history)
                    DispatchQueue.main.async { self.tableView.reloadData() }
                }
                //self.updateUI()
            }
        }
    }
}

// MARK: - ResponseTableViewController TableView Delegate

extension ResponseTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.mode == .info && section == 0 { return 7 }
        if self.mode == .raw && section == 1 { return 2 }
        if self.mode == .preview && section == 2 { return 2 }
        return 0
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0:
            if self.mode == .info {
                if self.data == nil {  // For requests which has not been sent once
                    if indexPath.row == InfoCellId.helpCell.rawValue { return 44 }
                    return 0
                } else {
                    guard let data = self.data else { return 0 }
                    let cellId = InfoCellId(rawValue: indexPath.row)
                    switch cellId {
                    case .spacerBeforeInfoCell:
                        return 24
                    case .infoCell:
                        return 81
                    case .headerTitleCell:
                        if data.getResponseHeaders().isEmpty { return 0 }
                        return 44
                    case .headersViewCell:
                        if data.getResponseHeaders().isEmpty { return 0 }
                        self.headersViewCell.tableView.invalidateIntrinsicContentSize()
                        self.headersViewCell.invalidateIntrinsicContentSize()
                        return self.headerCellHeight == 0 ? UITableView.automaticDimension : self.headerCellHeight
                    case .cookiesTitleCell:
                        Log.debug("cookies: \(String(describing: self.data?.cookies))")
                        if data.cookies.isEmpty { return 0 }
                        return 44
                    case .cookiesViewCell:
                        if data.cookies.isEmpty { return 0 }
                        self.cookiesViewCell.tableView.invalidateIntrinsicContentSize()
                        self.cookiesViewCell.invalidateIntrinsicContentSize()
                        return self.cookieCellHeight == 0 ? UITableView.automaticDimension : self.cookieCellHeight
                    case .detailsTitleCell:
                        return 44
                    case .detailsViewCell:
                        self.detailsViewCell.tableView.invalidateIntrinsicContentSize()
                        self.detailsViewCell.invalidateIntrinsicContentSize()
                        return self.detailsCellHeight == 0 ? UITableView.automaticDimension : self.detailsCellHeight
                    default:
                        return 0
                    }
                }
            }
        case 1:
            return 0
        case 2:
            return 0
        default:
            return 0
        }
        return UITableView.automaticDimension
    }
}

//extension ResponseViewController: UITableViewDelegate, UITableViewDataSource {
//    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//        return 1
//    }
//
//    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//        let cell = tableView.dequeueReusableCell(withIdentifier: "responseCell", for: indexPath) as! ResponseCell
//        cell.history = self.history
//        cell.mode = self.mode
//        cell.updateUI()
//        return cell
//    }
//}