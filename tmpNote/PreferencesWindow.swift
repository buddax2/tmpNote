//
//  PreferencesWindow.swift
//  tmpNote
//
//  Created by BUDDAx2 on 9/25/17.
//  Copyright © 2017 BUDDAx2. All rights reserved.
//

import AppKit
import MASShortcut

let kFontSizeKey = "FontSize"

protocol PreferencesDelegate: class {
    func updateFontSize()
}


class PreferencesWindowController: NSWindowController {
    
}

extension PreferencesWindowController {
    
    static func freshController() -> PreferencesWindowController {
        
        let storyBoard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
        let identifier = NSStoryboard.SceneIdentifier("PreferencesWindowController")
        guard let vc = storyBoard.instantiateController(withIdentifier: identifier) as? PreferencesWindowController else {
            
            fatalError("Can't instantiate PreferencesWindowController. Check Main.storyboard")
        }
        
        return vc
    }
}


class GeneralViewController: NSViewController {

    @IBOutlet weak var launchAtStartupCheckbox: NSButton!
    @IBOutlet weak var fontSizeMenu: NSMenu!
    @IBOutlet weak var fontSizePopUpButton: NSPopUpButton!
    @IBOutlet var shortcutView: MASShortcutView! {
        didSet {
            shortcutView.associatedUserDefaultsKey = GeneralViewController.kPreferenceGlobalShortcut
        }
    }
    
    static let kPreferenceGlobalShortcut = "GlobalShortcut"
    let fontSizes = [8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 36, 48, 72]
    weak var delegate: PreferencesDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        fontSizes.forEach {
            let menuItem = NSMenuItem(title: String($0), action: #selector(changeFontSize(_:)), keyEquivalent: "")
            menuItem.tag = $0
            fontSizeMenu.addItem(menuItem)
        }
        
        if let fontSize = UserDefaults.standard.object(forKey: kFontSizeKey) as? Int {
            fontSizePopUpButton.select(fontSizeMenu.item(withTag: fontSize))
        }
        
        MASShortcutBinder.shared().bindShortcut(withDefaultsKey: GeneralViewController.kPreferenceGlobalShortcut, toAction: {
            let appDelegate = NSApplication.shared.delegate as! AppDelegate
            appDelegate.togglePopover(self)
        })
    }
    
    @IBAction func toggleLaunchState(_ sender: NSButton) {
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.setupLaunchOnStartup()
    }
    
    @objc fileprivate func changeFontSize(_ sender: NSMenuItem) {
        UserDefaults.standard.set(sender.tag, forKey: kFontSizeKey)
        delegate?.updateFontSize()
    }
    
}
