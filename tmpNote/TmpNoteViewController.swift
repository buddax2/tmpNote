//
//  TmpNoteViewController.swift
//  tmpNote
//
//  Created by BUDDAx2 on 9/24/17.
//  Copyright © 2017 BUDDAx2. All rights reserved.
//

import Cocoa

class TmpNoteViewController: NSViewController {

    static private let kPreviousSessionTextKey = "PreviousSessionText"
    
    @IBOutlet var appMenu: NSMenu!
    @IBOutlet weak var menuIcon: NSButton!
    @IBOutlet var textView: NSTextView! {
        didSet {
            setupTextView()
            loadPreviousText()
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

        let fontSize = UserDefaults.standard.value(forKey: kFontSizeKey) as? CGFloat ?? 20
        let font = NSFont.systemFont(ofSize: fontSize)
        textView.textStorage?.font = font
    }
    
    func loadPreviousText() {
        if let prevText = UserDefaults.standard.string(forKey: TmpNoteViewController.kPreviousSessionTextKey)  {
            textView.string = prevText
        }
        else {
            textView.string = ""
        }
    }
    
    func saveText() {
        UserDefaults.standard.set(textView.string, forKey: TmpNoteViewController.kPreviousSessionTextKey)
    }
    
    ///Close popover if Esc key is pressed
    override func cancelOperation(_ sender: Any?) {
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.closePopover()
    }
    
    @IBAction func showMenu(_ sender: NSButton) {
        let p = NSPoint(x: 0, y: sender.frame.height)
        appMenu.popUp(positioning: nil, at: p, in: sender)
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
    
    func updateFontSize() {
        setupTextView()
    }
}
