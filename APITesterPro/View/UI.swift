//
//  UI.swift
//  APITesterPro
//
//  Created by Jaseem V V on 05/12/19.
//  Copyright © 2019 Jaseem V V. All rights reserved.
//

import Foundation
import UIKit
import MobileCoreServices  // For document picker
import UniformTypeIdentifiers  // For document picker

class UI {
    private static var toastQueue: Set<String> = Set<String>()
    private static var isToastPresenting = false
    
    static func setGlobalStyle() {
        self.clearBackButtonText()
    }
    
    static func clearBackButtonText() {
        // Clear back button text
        let BarButtonItemAppearance = UIBarButtonItem.appearance()
        BarButtonItemAppearance.setTitleTextAttributes([.foregroundColor: UIColor.clear, .backgroundColor: UIColor.clear], for: .normal)
        BarButtonItemAppearance.setTitleTextAttributes([.foregroundColor: UIColor.clear, .backgroundColor: UIColor.clear], for: .highlighted)
        BarButtonItemAppearance.setTitleTextAttributes([.foregroundColor: UIColor.clear, .backgroundColor: UIColor.clear], for: .selected)
    }
    
    static func roundTopCornersWithBorder(view: UIView, borderColor: UIColor? = nil, name: String) {
        // Round corners with mask
        let path = UIBezierPath(roundedRect: view.bounds, byRoundingCorners:[.topLeft, .topRight], cornerRadii: CGSize(width: 12.0, height: 12.0))
        let layer = CAShapeLayer()
        layer.path = path.cgPath
        view.layer.mask = layer

        // Remove border if present
        if let layers = view.layer.sublayers {
            for layer in layers {
                if layer.name == name {
                    Log.debug("removed border layer")
                    layer.removeFromSuperlayer()
                    break
                }
            }
        }
        
        // Add border
        let borderLayer = CAShapeLayer()
        borderLayer.name = name
        borderLayer.path = layer.path
        borderLayer.fillColor = UIColor.clear.cgColor
        Log.debug("updating top border")
        borderLayer.frame = view.bounds
        view.layer.addSublayer(borderLayer)
    }
    
    /// Return a done button for right navigation bar item. The button is bold than the default cancel button.
    static func getNavbarTopDoneButton() -> UIButton {
        let btn = UIButton(type: .custom)
        btn.setTitle("Done", for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        btn.setTitleColor(btn.tintColor, for: .normal)
        return btn
    }
    
    static func pushScreen(_ navVC: UINavigationController, storyboardId: String) {
        if let storyboard = navVC.storyboard {
            let vc = storyboard.instantiateViewController(withIdentifier: storyboardId)
            navVC.pushViewController(vc, animated: true)
        }
    }
    
    static var isDarkMode: Bool {
        if #available(iOS 12.0, *) {
            return UIScreen.main.traitCollection.userInterfaceStyle == .dark
        }
        return false
    }
           
    /// Present the given view controller from the storyboard
    static func presentScreen(_ vc: UIViewController, storyboard: UIStoryboard, storyboardId: String) -> UIViewController {
        let screen = storyboard.instantiateViewController(withIdentifier: storyboardId)
        vc.present(screen, animated: true, completion: nil)
        return screen
    }
   
    /// Push the given view controller from the storyboard
    static func pushScreen(_ vc: UINavigationController, storyboard: UIStoryboard, storyboardId: String) {
        let navVC = storyboard.instantiateViewController(withIdentifier: storyboardId)
        navVC.hidesBottomBarWhenPushed = true
        vc.pushViewController(navVC, animated: true)
    }
   
    static func hideNavigationBar(_ navVC: UINavigationController) {
        navVC.setNavigationBarHidden(true, animated: true)
    }
   
    static func showNavigationBar(_ navVC: UINavigationController) {
        navVC.setNavigationBarHidden(false, animated: true)
    }
   
    /// Remove the text from navigation bar back button. The text depends on the master view. So this has to be called in the `viewWillDisappear`.
    /// - Parameter navItem: The navigationItem as in `self.navigationItem`.
    static func clearNavigationBackButtonText(_ navItem: UINavigationItem) {
        navItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
    }
   
    /// Handler method which queues toast events for display
    static func displayToast(_ msg: String) {
        if self.isToastPresenting {
            self.toastQueue.insert(msg)
        } else {
            if let appDel = UIApplication.shared.delegate as? AppDelegate, let window = appDel.window, let nav = window.rootViewController as? UINavigationController,
                let vc = nav.viewControllers.last {
                self.viewToast(msg, vc: vc)
            }
        }
    }
    
    /// Display an action sheet.
    /// - Parameters:
    ///     - vc: Any view controller object.
    ///     - title: An optional title string.
    ///     - message: An optional message string.
    ///     - cancelText: Cancel button text.
    ///     - otherButtonText: Other button text.
    ///     - cancelStyle: The alert style for cancel.
    ///     - otherStyle: The alert style for the other option.
    ///     - cancelCallback: Callback function on cancel.
    ///     - otherCallback: Callback function when other button is tapped.
    static func viewActionSheet(vc: UIResponder, title: String? = nil, message: String? = nil,
                                cancelText: String, otherButtonText: String,
                                cancelStyle: UIAlertAction.Style, otherStyle: UIAlertAction.Style,
                                cancelCallback: (() -> Void)? = nil, otherCallback: (() -> Void)? = nil) {
        guard let aVC = vc as? UIViewController else { return }
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        alertVC.addAction(UIAlertAction(title: cancelText, style: cancelStyle, handler: { _ in
            if let cb = cancelCallback { cb() }
        }))
        alertVC.addAction(UIAlertAction(title: otherButtonText, style: otherStyle, handler: {_ in
            if let cb = otherCallback { cb() }
        }))
        alertVC.modalPresentationStyle = .popover
        if let popoverPresentationController = alertVC.popoverPresentationController {
            popoverPresentationController.sourceView = aVC.view
            popoverPresentationController.sourceRect = aVC.view.bounds
            popoverPresentationController.permittedArrowDirections = []
        }
        DispatchQueue.main.async { aVC.present(alertVC, animated: true, completion: nil) }
    }
    
    /// Display an alert box.
    /// - Parameters:
    ///     - vc: A view controller conforming to `ViewControllerProtocol`.
    ///     - title: An optional title string.
    ///     - message: An optional message string.
    ///     - cancelText: Cancel button text.
    ///     - otherButtonText: Other button text.
    ///     - cancelCallback: Callback function on cancel.
    ///     - otherCallback: Callback function when other button is tapped.
    static func viewAlert(vc: UIResponder, title: String? = nil, message: String? = nil, cancelText: String, otherButtonText: String,
                          cancelStyle: UIAlertAction.Style, otherStyle: UIAlertAction.Style,
                          cancelCallback: (() -> Void)? = nil, otherCallback: (() -> Void)? = nil) {
        guard let aVC = vc as? UIViewController else { return }
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: cancelText, style: cancelStyle, handler: { _ in
            if let cb = cancelCallback { cb() }
        }))
        alertVC.addAction(UIAlertAction(title: otherButtonText, style: otherStyle, handler: {_ in
            if let cb = otherCallback { cb() }
        }))
        alertVC.modalPresentationStyle = .popover
        if let popoverPresentationController = alertVC.popoverPresentationController {
            popoverPresentationController.sourceView = aVC.view
            popoverPresentationController.sourceRect = aVC.view.bounds
            popoverPresentationController.permittedArrowDirections = []
        }
        DispatchQueue.main.async { aVC.present(alertVC, animated: true, completion: nil) }
    }
   
    /// Display toast using the presented view controller
    static func viewToast(_ message: String, hideSec: Double? = 3, vc: UIViewController, completion: (() -> Void)? = nil) {
        self.isToastPresenting = true
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .actionSheet)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + (hideSec ?? 3), execute: {
            self.isToastPresenting = false
            alert.dismiss(animated: true, completion: {
                if !self.toastQueue.isEmpty, let msg = self.toastQueue.popFirst() {
                    self.viewToast(msg, hideSec: hideSec, vc: vc, completion: completion)
                }
            })
        })
        alert.modalPresentationStyle = .popover
        if let popoverPresentationController = alert.popoverPresentationController {
            popoverPresentationController.sourceView = vc.view
            popoverPresentationController.sourceRect = vc.view.bounds
            popoverPresentationController.permittedArrowDirections = []
        }
        DispatchQueue.main.async { vc.present(alert, animated: true, completion: completion) }
    }
   
    static func activityIndicator() -> UIActivityIndicatorView {
        let activityIndicator: UIActivityIndicatorView = UIActivityIndicatorView.init(style: UIActivityIndicatorView.Style.medium)
        activityIndicator.alpha = 1.0
        activityIndicator.center = CGPoint(x: UIScreen.main.bounds.size.width / 2, y: UIScreen.main.bounds.size.height / 2)
        activityIndicator.startAnimating()
        return activityIndicator
    }
   
    static func showLoading(_ indicator: UIActivityIndicatorView?) {
        DispatchQueue.main.async {
            guard let indicator = indicator else { return }
            indicator.startAnimating()
            indicator.backgroundColor = UIColor.white
        }
    }

    static func hideLoading(_ indicator: UIActivityIndicatorView?) {
        guard let indicator = indicator else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.0, execute: {
            indicator.stopAnimating()
            indicator.hidesWhenStopped = true
        })
    }

    static func addActivityIndicator(indicator: UIActivityIndicatorView?, view: UIView) {
        guard let indicator = indicator else { return }
        DispatchQueue.main.async {
            indicator.style = UIActivityIndicatorView.Style.medium
            indicator.center = view.center
            view.addSubview(indicator)
        }
    }
   
    static func removeActivityIndicator(indicator: UIActivityIndicatorView?) {
        guard let indicator = indicator else { return }
        DispatchQueue.main.async {
            indicator.removeFromSuperview()
        }
    }
    
    /// A loading indicator snipper
    private static var spinner: (UITableView) -> UIActivityIndicatorView = { tableView in
        let s = UIActivityIndicatorView(style: UIActivityIndicatorView.Style.medium)
        s.startAnimating()
        s.frame = CGRect(x: CGFloat(0), y: CGFloat(0), width: tableView.bounds.width, height: CGFloat(44))
        return s
    }
    
    /// Show loading spinner at the bottom of the given table view
    static func showLoadingForTableView(_ tableView: UITableView) {
        tableView.tableFooterView = self.spinner(tableView)
        tableView.tableFooterView?.isHidden = false
    }

    /// Hide loading spinner for the given table view if present
    static func hideLoadingForTableView(_ tableView: UITableView) {
        tableView.tableFooterView?.subviews.forEach({ view in
            if view == self.spinner(tableView) {
                view.removeFromSuperview()
            }
        })
        tableView.tableFooterView?.isHidden = true
    }
    
    
    /// Display circular progress indicator with a custom background. The default activity indicator is having a white background.
    /// - Parameters:
    ///   - bgView: The activity indicator will be added to this view and this view will be added to the main view to display the indicator. This reference is later required to remove the indicator from the view
    ///   - mainView: The view controller's main view where the activity indicator will be added
    ///   - shouldDisableInteraction: Whether the UI should not respond until the indicator is removed
    static func showCustomActivityIndicator(_ bgView: UIView, mainView: UIView, shouldDisableInteraction: Bool = false) {
        guard let window = UIApplication.shared.windows.first(where: \.isKeyWindow) else { return }
        let indicator = UIActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 35, height: 35))

        bgView.layer.cornerRadius = 5
        bgView.clipsToBounds = true
        bgView.isOpaque = false
        bgView.backgroundColor = App.Color.activityIndicatorBg

        indicator.style = UIActivityIndicatorView.Style.medium
        indicator.color = App.Color.activityIndicator
        indicator.startAnimating()

        bgView.frame = CGRect(x: 0, y: 0, width: 35, height: 35)
        bgView.center = mainView.center;

        bgView.addSubview(indicator)
        mainView.addSubview(bgView)
        
        // auto resizing contraint is required to center it to the screen. Other methods are not properly centering
        bgView.translatesAutoresizingMaskIntoConstraints = false
        bgView.centerXAnchor.constraint(equalTo: window.centerXAnchor).isActive = true
        bgView.centerYAnchor.constraint(equalTo: window.centerYAnchor).isActive = true
        indicator.centerXAnchor.constraint(equalTo: bgView.centerXAnchor).isActive = true
        indicator.centerYAnchor.constraint(equalTo: bgView.centerYAnchor).isActive = true
        
        if shouldDisableInteraction {
            mainView.isUserInteractionEnabled = false
        }
    }
    
    /// Remove the custom activity indicator from the parent view
    /// - Parameter bgView: The activity indicator view
    static func removeCustomActivityIndicator(_ bgView: UIView) {
        bgView.superview?.isUserInteractionEnabled = true
        bgView.removeFromSuperview()
    }
        
    static func getTextHeight(_ text: String, width: CGFloat, font: UIFont) -> CGFloat {
        let frame = NSString(string: text)
                        .boundingRect(with: CGSize(width: width, height: .infinity),
                                      options: [.usesFontLeading, .usesLineFragmentOrigin],
                                      attributes: [.font : font],
                                      context: nil)
        return frame.size.height
    }
    
    /// Returns the height of the navigation bar.
    /// - Parameter navVC: The current navigation controller (optional).
    static func getNavBarHeight(navVC: UINavigationController? = nil) -> CGFloat {
        let vc = navVC != nil ? navVC! : UINavigationController()
        return vc.navigationBar.frame.size.height
    }
    
    static func endEditing() {
        UIApplication.shared.sendAction(#selector(UIApplication.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    static func addCornerRadius(_ tv: UITextView) {
        tv.layer.cornerRadius = 4
        tv.layer.borderColor = UIColor(named: "cell-separator-bg")?.cgColor
        tv.layer.borderWidth = 0.5
        tv.clipsToBounds = true
    }
    
    /// Display document picker dialog which opens the Files app to export JSON data. In iOS 14 and above we can move the created file to the selected folder. In iOS 12, 13 user needs to first pick a file to write.
    static func displayDocumentPickerForExport(url: URL, delegate: UIDocumentPickerDelegate?, tvVc: APITesterProTableViewController?, vc: APITesterProViewController?) {
        var documentPicker: UIDocumentPickerViewController
        if #available(iOS 14.0, *) {
            documentPicker = UIDocumentPickerViewController(forExporting: [url])  // the temp file will be moved
        } else {
            documentPicker = UIDocumentPickerViewController(documentTypes: [String(kUTTypeJSON)], in: .open)
        }
        documentPicker.delegate = delegate
        documentPicker.allowsMultipleSelection = false
        if let _vc = tvVc ?? vc {
            _vc.present(documentPicker, animated: true, completion: nil)
        }
    }
    
    static func displayDocumentPickerForImport(delegate: UIDocumentPickerDelegate?, tvVc: APITesterProTableViewController?, vc: APITesterProViewController?) {
        var documentPicker: UIDocumentPickerViewController
        if #available(iOS 14.0, *) {
            documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.json])
        } else {
            documentPicker = UIDocumentPickerViewController(documentTypes: [String(kUTTypeJSON)], in: .open)
        }
        documentPicker.delegate = delegate
        documentPicker.allowsMultipleSelection = false
        if let _vc = tvVc ?? vc {
            _vc.present(documentPicker, animated: true, completion: nil)
        }
    }
    
    static func getKeyWindow() -> UIWindow? {
        if #available(iOS 15, *) {  // 15 and above
            return UIApplication.shared
                .connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                .last
        } else {  // 13 to 15
            return UIApplication.shared
                .connectedScenes
                .flatMap { ($0 as? UIWindowScene)?.windows ?? [] }
                .last { $0.isKeyWindow }
        }
    }
    
    /// Returns the current device type. iPhone or iPad.
    static func getDeviceType() -> UIUserInterfaceIdiom {
        return UIDevice.current.userInterfaceIdiom
    }
    
    /// Returns the current device orientation. Portrait or Landscape.
    static func getCurrentDeviceOrientation() -> UIDeviceOrientation {
        return UIDevice.current.orientation
    }
}

extension UIView {
    @IBInspectable
    var cornerRadius: CGFloat {
        get {
            return layer.cornerRadius
        }
        set {
            layer.cornerRadius = newValue
        }
    }

    @IBInspectable
    var borderWidth: CGFloat {
        get {
            return layer.borderWidth
        }
        set {
            layer.borderWidth = newValue
        }
    }

    @IBInspectable
    var borderColor: UIColor? {
        get {
            if let color = layer.borderColor {
                return UIColor(cgColor: color)
            }
            return nil
        }
        set {
            if let color = newValue {
                layer.borderColor = color.cgColor
            } else {
                layer.borderColor = nil
            }
        }
    }

    @IBInspectable
    var shadowRadius: CGFloat {
        get {
            return layer.shadowRadius
        }
        set {
            layer.shadowRadius = newValue
        }
    }

    @IBInspectable
    var shadowOpacity: Float {
        get {
            return layer.shadowOpacity
        }
        set {
            layer.shadowOpacity = newValue
        }
    }

    @IBInspectable
    var shadowOffset: CGSize {
        get {
            return layer.shadowOffset
        }
        set {
            layer.shadowOffset = newValue
        }
    }

    @IBInspectable
    var shadowColor: UIColor? {
        get {
            if let color = layer.shadowColor {
                return UIColor(cgColor: color)
            }
            return nil
        }
        set {
            if let color = newValue {
                layer.shadowColor = color.cgColor
            } else {
                layer.shadowColor = nil
            }
        }
    }
    
    func addTopBorderWithColor(color: UIColor, width: CGFloat) {
        let border = CALayer()
        border.backgroundColor = color.cgColor
        border.frame = CGRect(x: 0, y: 0, width: self.frame.size.width, height: width)
        self.layer.addSublayer(border)
    }

    func addRightBorderWithColor(color: UIColor, width: CGFloat) {
        let border = CALayer()
        border.backgroundColor = color.cgColor
        border.frame = CGRect(x: self.frame.size.width - width, y: 0, width: width, height: self.frame.size.height)
        self.layer.addSublayer(border)
    }

    func addBottomBorderWithColor(color: UIColor, width: CGFloat, name: String) {
        let border = CALayer()
        border.name = name
        border.backgroundColor = color.cgColor
        border.frame = CGRect(x: 0, y: self.frame.size.height - width, width: self.frame.size.width, height: width)
        self.layer.addSublayer(border)
    }
    
    func addLeftBorderWithColor(color: UIColor, width: CGFloat) {
        let border = CALayer()
        border.backgroundColor = color.cgColor
        border.frame = CGRect(x: 0, y: 0, width: width, height: self.frame.size.height)
        self.layer.addSublayer(border)
    }
    
    func removeBottomBorder(name: String) {
        self.layer.sublayers?.forEach({ aLayer in
            if aLayer.name == name {
                aLayer.removeFromSuperlayer()
                return
            }
        })
    }

    func addBorderWithColor(color: UIColor, width: CGFloat) {
        self.layer.cornerRadius = 5
        self.layer.borderWidth = width
        self.layer.borderColor = color.cgColor
    }

    func removeBorder() {
        self.layer.borderColor = UIColor.clear.cgColor
    }
}

public extension UILabel {
    func textWidth() -> CGFloat {
        return UILabel.textWidth(label: self)
    }
    
    static func textWidth(label: UILabel) -> CGFloat {
        return textWidth(label: label, text: label.text!)
    }
    
    static func textWidth(label: UILabel, text: String) -> CGFloat {
        return textWidth(font: label.font, text: text)
    }
    
    static func textWidth(font: UIFont, text: String) -> CGFloat {
        let myText = text as NSString
        let rect = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        let labelSize = myText.boundingRect(with: rect, options: .usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font: font], context: nil)
        return ceil(labelSize.width)
    }
    
    func textHeight(width: CGFloat) -> CGFloat {
        guard let text = text else { return 0 }
        return text.height(width: width, font: font)
    }

    func attributedTextHeight(width: CGFloat) -> CGFloat {
        guard let attributedText = attributedText else { return 0 }
        return attributedText.height(width: width)
    }
}

extension String {
    func height(width: CGFloat, font: UIFont) -> CGFloat {
        let maxSize = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        let actualSize = self.boundingRect(with: maxSize, options: [.usesLineFragmentOrigin], attributes: [.font : font], context: nil)
        return actualSize.height
    }
}

extension NSAttributedString {
    func height(width: CGFloat) -> CGFloat {
        let maxSize = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        let actualSize = boundingRect(with: maxSize, options: [.usesLineFragmentOrigin], context: nil)
        return actualSize.height
    }
}

extension UITableView {
//    func reloadData(completion: @escaping () -> ()) {
//        UIView.animate(withDuration: 0, animations: { self.reloadData() }, completion: { _ in
//            completion()
//        })
//    }
}

extension UIColor {
    public static func randomColors(_ count: Int) -> [UIColor] {
        return (0..<count).map { _ -> UIColor in
            randomColor()
        }
    }
    
    public static func randomColor() -> UIColor {
        let redValue = CGFloat.random(in: 0...1)
        let greenValue = CGFloat.random(in: 0...1)
        let blueValue = CGFloat.random(in: 0...1)
        
        let randomColor = UIColor(red: redValue, green: greenValue, blue: blueValue, alpha: 1.0)
        return randomColor
    }
}
