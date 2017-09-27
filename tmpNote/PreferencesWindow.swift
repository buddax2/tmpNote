//
//  PreferencesWindow.swift
//  tmpNote
//
//  Created by BUDDAx2 on 9/25/17.
//  Copyright © 2017 BUDDAx2. All rights reserved.
//

import AppKit
import MASShortcut


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

    @IBOutlet weak var launchAtStartupCheckbox: NSButton! {
        didSet {
            launchAtStartupCheckbox.state = NSControl.StateValue(UserDefaults.standard.bool(forKey: "LaunchOnStartup") == false ? 0 : 1)
        }
    }
    @IBOutlet var shortcutView: MASShortcutView! {
        didSet {
            shortcutView.associatedUserDefaultsKey = GeneralViewController.kPreferenceGlobalShortcut
        }
    }
    
    static let kPreferenceGlobalShortcut = "GlobalShortcut"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        MASShortcutBinder.shared().bindShortcut(withDefaultsKey: GeneralViewController.kPreferenceGlobalShortcut, toAction: {
            let appDelegate = NSApplication.shared.delegate as! AppDelegate
            appDelegate.togglePopover(self)
        })
    }
    
    @IBAction func toggleLaunchState(_ sender: NSButton) {
        let shouldLaunch = sender.state.rawValue == 1
        
        UserDefaults.standard.set(shouldLaunch, forKey: "LaunchOnStartup")
        
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.setupLaunchOnStartup()
    }
    
}
