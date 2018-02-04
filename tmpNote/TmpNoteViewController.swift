//
//  TmpNoteViewController.swift
//  tmpNote
//
//  Created by BUDDAx2 on 9/24/17.
//  Copyright © 2017 BUDDAx2. All rights reserved.
//

import Cocoa

class TmpNoteViewController: NSViewController {

    static let kFontSizeKey = "FontSize"
    static let kFontSizes = [8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 36, 48, 72]
    static var defaultFontSize: Int {
        return kFontSizes[4]
    }

    static private let kPreviousSessionTextKey = "PreviousSessionText"
    
    @IBOutlet weak var menuView: NSView! {
        didSet {
            menuView.isHidden = true // make it hidden here to be able to see it in the storyboard
        }
    }
    @IBOutlet var appMenu: NSMenu!
    @IBOutlet weak var menuIcon: NSButton!
    @IBOutlet var textView: NSTextView! {
        didSet {
            setupTextView()
            loadPreviousText()
        }
    }
    @IBOutlet weak var lockButton: NSButton! {
        didSet {
            let isLocked = UserDefaults.standard.bool(forKey: "locked")
            lockButton.image = isLocked ? NSImage(named: NSImage.Name(rawValue: "NSLockLockedTemplate")) : NSImage(named: NSImage.Name(rawValue: "NSLockUnlockedTemplate"))
            lockButton.toolTip = isLocked ? "Do Not Hide on Deactivate" : "Hide on Deactivate"
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.

    }
    
    func willAppear() {
        // make textview focused
        textView?.window?.makeKeyAndOrderFront(self)
    }
    
    @objc fileprivate func setupTextView() {

        let fontSize = UserDefaults.standard.value(forKey: TmpNoteViewController.kFontSizeKey) as? Int ?? TmpNoteViewController.defaultFontSize
        setFontSize(size: CGFloat(fontSize))
    }
    
    fileprivate func setFontSize(size: CGFloat) {
        let font = NSFont.systemFont(ofSize: size)
        textView.font = font
    }
    
    func loadPreviousText() {
        if let prevText = UserDefaults.standard.string(forKey: TmpNoteViewController.kPreviousSessionTextKey)  {
            textView.string = prevText
        }
        else {
            textView.string = ""
        }
    }
    
    @IBAction func lockAction(_ sender: Any) {
        let isLocked = UserDefaults.standard.bool(forKey: "locked")
        UserDefaults.standard.set(!isLocked, forKey: "locked")
        lockButton.image = isLocked ? NSImage(named: NSImage.Name(rawValue: "NSLockUnlockedTemplate")) : NSImage(named: NSImage.Name(rawValue: "NSLockLockedTemplate"))
        lockButton.toolTip = isLocked ? "Do Not Hide on Deactivate" : "Hide on Deactivate"
    }
    
    func saveText() {
        UserDefaults.standard.set(textView.string, forKey: TmpNoteViewController.kPreviousSessionTextKey)
    }
    
    ///Close popover if Esc key is pressed
    override func cancelOperation(_ sender: Any?) {
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.closePopover()
    }
    
    @IBAction func showAppMenu(_ sender: NSButton) {
        let p = NSPoint(x: 0, y: sender.frame.height)
        appMenu.popUp(positioning: nil, at: p, in: sender)
    }

    @IBAction func showMenuView(_ sender: NSButton) {
        menuView.isHidden = !menuView.isHidden
        return
    }

    @IBAction func decreaseFontSize(_ sender: Any) {
        let fontSize = UserDefaults.standard.object(forKey: TmpNoteViewController.kFontSizeKey) as? Int ?? TmpNoteViewController.defaultFontSize
        
        guard let currentFontIndex = TmpNoteViewController.kFontSizes.index(of: fontSize) else { return }
        let nextFontSize = currentFontIndex-1 > 0 ? TmpNoteViewController.kFontSizes[currentFontIndex-1] : TmpNoteViewController.kFontSizes.first

        
        if let newFontSize = nextFontSize {
            UserDefaults.standard.set(newFontSize, forKey: TmpNoteViewController.kFontSizeKey)
            self.setFontSize(size: CGFloat(newFontSize))
        }
    }
    
    @IBAction func clearAction(_ sender: Any) {
        textView.string = ""
        saveText()
    }
    
    
    @IBAction func increaseFontSize(_ sender: Any) {
        let fontSize = UserDefaults.standard.object(forKey: TmpNoteViewController.kFontSizeKey) as? Int ?? TmpNoteViewController.defaultFontSize
        
        guard let currentFontIndex = TmpNoteViewController.kFontSizes.index(of: fontSize) else { return }
        let nextFontSize = currentFontIndex+1 < TmpNoteViewController.kFontSizes.count ? TmpNoteViewController.kFontSizes[currentFontIndex+1] : TmpNoteViewController.kFontSizes.last
        
        if let newFontSize = nextFontSize {
            UserDefaults.standard.set(newFontSize, forKey: TmpNoteViewController.kFontSizeKey)
            self.setFontSize(size: CGFloat(newFontSize))
        }
    }
    
    @IBAction func shareAction(_ sender: NSButton) {
        let sharedItems = [textView.string];
        
        let servicePicker = NSSharingServicePicker(items: sharedItems)
        servicePicker.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
    }
    
    @IBAction func openPreferences(_ sender: Any) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        (appDelegate.preferences.contentViewController as? GeneralViewController)?.delegate = self
        appDelegate.openPreferences()
    }
    
    @IBAction func terminateApp(_ sender: Any) {
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.quitAction()
    }
    
    
}

extension TmpNoteViewController {
    
    static func freshController() -> TmpNoteViewController {
        
        let storyBoard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
        let identifier = NSStoryboard.SceneIdentifier("TmpNoteViewController")
        guard let vc = storyBoard.instantiateController(withIdentifier: identifier) as? TmpNoteViewController else {
            
            fatalError("Can't instantiate TmpNoteViewController. Check Main.storyboard")
        }
        
        return vc
    }
}

extension TmpNoteViewController: PreferencesDelegate {
    
    func settingsDidChange() {
        setupTextView()
    }
}
