//
//  RequestViewController.swift
//  Restor
//
//  Created by jsloop on 09/12/19.
//  Copyright © 2019 EstoApps. All rights reserved.
//

import Foundation
import UIKit
import InfiniteLayout

class HeaderCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var nameLbl: UILabel!
    
    func update(index: Int, text: String) {
        self.nameLbl.text = text
    }
}

struct InfoField {
    var name: String
    var value: Any
}

class RequestViewController: UITableViewController {
    @IBOutlet weak var headerCollectionView: InfiniteCollectionView!
    @IBOutlet weak var requestInfoCell: UITableViewCell!
    @IBOutlet weak var descriptionTextView: UITextView!
    @IBOutlet var infoTableViewManager: InfoTableViewManager!
    @IBOutlet weak var infoTableView: UITableView!
    let header: [String] = ["Description", "Headers", "URL Params", "Body", "Auth", "Options"]
    lazy var infoxs: [UIView] = {
        return [self.descriptionTextView, self.infoTableView]
    }()
    private var requestInfo: RequestHeaderInfo = .description
    private var headerData: [InfoField] = []
    private var urlParamsData: [InfoField] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Log.debug("request vc did load")
        self.headerCollectionView.infiniteLayout.isEnabled = false
        self.infoTableViewManager.delegate = self
//        self.infoTableView.delegate = self.infoTableViewManager
//        self.infoTableView.dataSource = self.infoTableViewManager
        self.infoTableView.estimatedRowHeight = 44
        self.infoTableView.rowHeight = UITableView.automaticDimension
        self.headerCollectionView.reloadData()
        self.hideInfoElements()
        self.descriptionTextView.isHidden = false
    }
    
    func hideInfoElements() {
        self.infoxs.forEach { v in v.isHidden = true }
    }
    
    func processCollectionViewTap(_ info: RequestHeaderInfo) {
        Log.debug("selected element: \(String(describing: info))")
        self.requestInfo = info
        self.hideInfoElements()
        switch info {
        case .description:
            self.descriptionTextView.isHidden = false
        case .headers:
            self.infoTableView.isHidden = false
            self.infoTableView.reloadData()
        default:
            break
        }
    }
}

extension RequestViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.header.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "headerCell", for: indexPath) as! HeaderCollectionViewCell
        let path = self.headerCollectionView.indexPath(from: indexPath)
        cell.update(index: path.row, text: self.header[path.row])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        var width: CGFloat = 0
        let row = indexPath.row
        if self.header.count > row {
            let text = self.header[row]
            width = UILabel.textWidth(font: UIFont.systemFont(ofSize: 16), text: text)
        }
        Log.debug("label width: \(width)")
        return CGSize(width: width, height: 22)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 12
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 4
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        Log.debug("collection view did select \(indexPath.row)")
        self.processCollectionViewTap(RequestHeaderInfo(rawValue: indexPath.row) ?? .description)
    }
}

extension RequestViewController: InfoTableViewDelegate {
    func currentRequestInfo() -> RequestHeaderInfo {
        return self.requestInfo
    }
    
    func model() -> [InfoField] {
        switch self.requestInfo {
        case .headers:
            return self.headerData
        case .urlParams:
            return self.urlParamsData
        default:
            return []
        }
    }
}

// MARK: - Header Info

protocol InfoTableViewDelegate: class {
    func currentRequestInfo() -> RequestHeaderInfo
    func model() -> [InfoField]
}

class InfoTableCell: UITableViewCell {
    @IBOutlet weak var keyTextField: EATextField!
    @IBOutlet weak var valueTextField: EATextField!
    @IBOutlet var keyTextFieldHeight: NSLayoutConstraint!
    @IBOutlet var valueTextFieldHeight: NSLayoutConstraint!
}

class InfoTableViewManager: NSObject, UITableViewDelegate, UITableViewDataSource {
    weak var delegate: InfoTableViewDelegate?
    private let textFieldBorderColor: UIColor = UITextField(frame: .zero).borderColor!
    
    override init() {
        super.init()
        Log.debug("info table view manager init")
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let delegate = self.delegate {
            return delegate.model().count + 2
        }
        return 2
    }
    
    func updateStyleForInfoFieldHeader(_ textField: EATextField, height: NSLayoutConstraint) {
        textField.isEnabled = false
        textField.isColor = false
        height.isActive = false
        height.constant = 32
        height.isActive = true
        textField.setNeedsDisplay()
    }
    
    func updateStyleForInfoField(_ textField: EATextField, height: NSLayoutConstraint) {
        textField.isEnabled = true
        textField.isColor = true
        height.isActive = false
        height.constant = 42
        height.isActive = true
        textField.setNeedsDisplay()
    }
    
    func updateStyleForInfoFieldRow(_ cell: InfoTableCell) {
        cell.keyTextField.borderStyle = .none
        cell.valueTextField.borderStyle = .none
        
        if cell.tag == 0 {
            self.updateStyleForInfoFieldHeader(cell.keyTextField, height: cell.keyTextFieldHeight)
            self.updateStyleForInfoFieldHeader(cell.valueTextField, height: cell.valueTextFieldHeight)
        } else {
            self.updateStyleForInfoField(cell.keyTextField, height: cell.keyTextFieldHeight)
            self.updateStyleForInfoField(cell.valueTextField, height: cell.valueTextFieldHeight)
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "infoCell", for: indexPath) as! InfoTableCell
        let row = indexPath.row
        cell.tag = row
        self.updateStyleForInfoFieldRow(cell)
        guard let delegate = self.delegate else { return cell }
        let model = delegate.model()
        
        switch delegate.currentRequestInfo() {
        case .headers:
            if row == 0 {
                cell.keyTextField.text = "Header Name"
                cell.valueTextField.text = "Header Value"
            }
            cell.keyTextField.placeholder = "Add Header Name"
            cell.valueTextField.placeholder = "Add Header Value"
        default:
            cell.keyTextField.text = ""
            cell.valueTextField.text = ""
        }
        
        if row < model.count {
            let x = model[row]
            cell.keyTextField.text = x.name
            cell.valueTextField.text = String(describing: x.value)
        }
        return cell
    }
}
