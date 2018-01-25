//
//  TodayViewController.swift
//  tmpNote todayWidget
//
//  Created by BUDDAx2 on 11/14/17.
//  Copyright © 2017 BUDDAx2. All rights reserved.
//

import Cocoa
import NotificationCenter

class TodayViewController: NSViewController, NCWidgetProviding {

    static public let suiteName = "Q2N8L37H44..tmpNote"
    static let kFontSizeKey = "FontSize"
    static let kFontSizes = [8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 36, 48, 72]
    static var defaultFontSize: Int {
        return kFontSizes[3]
    }
    
    static private let kPreviousSessionTextKey = "PreviousSessionText"

    @IBOutlet var textView: GrowingTextView! {
        didSet {
//            textView.delegate = self
            textView.textDelegate = self
            setupTextView()
            loadPreviousText()
        }
    }
    @IBOutlet weak var menuView: NSView! {
        didSet {
            menuView.isHidden = true // make it hidden here to be able to see it in the storyboard
        }
    }

    @IBOutlet weak var heightConstraint: NSLayoutConstraint!
    override var nibName: NSNib.Name? {
        return NSNib.Name("TodayViewController")
    }

    func widgetPerformUpdate(completionHandler: (@escaping (NCUpdateResult) -> Void)) {
        // Update your data and prepare for a snapshot. Call completion handler when you are done
        // with NoData if nothing has changed or NewData if there is new data since the last
        // time we called you
        setupTextView()
        loadPreviousText()
        completionHandler(.newData)
    }
    
    @objc fileprivate func setupTextView() {
        
        let fontSize = UserDefaults(suiteName: TodayViewController.suiteName)?.value(forKey: TodayViewController.kFontSizeKey) as? Int ?? TodayViewController.defaultFontSize
        setFontSize(size: CGFloat(fontSize))
    }

    fileprivate func setFontSize(size: CGFloat) {
        let font = NSFont.systemFont(ofSize: size)
        textView.textStorage?.font = font
    }

    func loadPreviousText() {
        if let prevText = UserDefaults(suiteName: TodayViewController.suiteName)?.string(forKey: TodayViewController.kPreviousSessionTextKey)  {
            textView.string = prevText
        }
        else {
            textView.string = "ччч"
        }
        
        textView.updateTextViewHeight()
    }
    
    func saveText() {
        let defaults = UserDefaults(suiteName: TodayViewController.suiteName)
        defaults?.set(textView.string, forKey: TodayViewController.kPreviousSessionTextKey)
        defaults?.synchronize()
    }

    
    @IBAction func changeFontSize(_ sender: NSSegmentedControl) {
        let fontSize = UserDefaults(suiteName: TodayViewController.suiteName)?.object(forKey: TodayViewController.kFontSizeKey) as? Int ?? TodayViewController.defaultFontSize
        
        guard let currentFontIndex = TodayViewController.kFontSizes.index(of: fontSize) else { return }
        var nextFontSize: Int?
        
        switch sender.selectedSegment {
        case 0: //make the font smaller
            nextFontSize = currentFontIndex-1 > 0 ? TodayViewController.kFontSizes[currentFontIndex-1] : TodayViewController.kFontSizes.first
        case 1:
            nextFontSize = currentFontIndex+1 < TodayViewController.kFontSizes.count ? TodayViewController.kFontSizes[currentFontIndex+1] : TodayViewController.kFontSizes.last
        default:
            nextFontSize = TodayViewController.defaultFontSize
        }
        
        if let newFontSize = nextFontSize {
            let defaults = UserDefaults(suiteName: TodayViewController.suiteName)
            defaults?.set(newFontSize, forKey: TodayViewController.kFontSizeKey)
            defaults?.synchronize()
            self.setFontSize(size: CGFloat(newFontSize))
        }
    }
    
    @IBAction func shareAction(_ sender: NSButton) {
        let sharedItems = [textView.string];
        
        let servicePicker = NSSharingServicePicker(items: sharedItems)
        servicePicker.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
    }

    @IBAction func showMenuView(_ sender: NSButton) {
        menuView.isHidden = !menuView.isHidden
        return
    }
}

extension TodayViewController: TextProtocol {
    func textDidChange(text: String?) {
        saveText()
    }
    
    func resizeParentViewToHeight(_ height:CGFloat) {
        heightConstraint.constant = height
    }
}

extension TodayViewController: NSTextViewDelegate {
    
    func textDidChange(_ notification: Notification) {
        saveText()
    }
}
