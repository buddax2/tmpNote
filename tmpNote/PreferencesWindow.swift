//
//  PreferencesWindow.swift
//  tmpNote
//
//  Created by BUDDAx2 on 9/25/17.
//  Copyright © 2017 BUDDAx2. All rights reserved.
//

import AppKit
import MASShortcut


protocol PreferencesDelegate: class {
    func settingsDidChange()
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

enum IconColor: Int {
    case `default`
    case red
    
    func color() -> NSColor {
        switch self {
        case .default:
            return .textColor
        case .red:
            return .red
        }
    }
}

class GeneralViewController: NSViewController {
    
    @IBOutlet weak var colorPicker: NSPopUpButton!
    @IBOutlet weak var colorView: NSStackView!
    @IBOutlet weak var launchAtStartupCheckbox: NSButton!
    @IBOutlet var shortcutView: MASShortcutView! {
        didSet {
            shortcutView.associatedUserDefaultsKey = GeneralViewController.kPreferenceGlobalShortcut
        }
    }
    
    static let kPreferenceGlobalShortcut = "GlobalShortcut"
    weak var delegate: PreferencesDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        MASShortcutBinder.shared().bindShortcut(withDefaultsKey: GeneralViewController.kPreferenceGlobalShortcut, toAction: {
            let appDelegate = NSApplication.shared.delegate as! AppDelegate
            appDelegate.togglePopover(self)
        })
    }
    
    @IBAction func toggleDynamicIcon(_ sender: Any) {
        let isDynamicIconON = UserDefaults.standard.bool(forKey: "DynamicIcon")
        colorView.isHidden = isDynamicIconON == false
        delegate?.settingsDidChange()
    }
    
    @IBAction func toggleLaunchState(_ sender: NSButton) {
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.setupLaunchOnStartup()
    }
    
    @IBAction func tintColorDidChange(_ sender: NSPopUpButton) {
        delegate?.settingsDidChange()
    }
    
    @IBAction func shopIconPopover(_ sender: NSButton) {
        let popover = NSPopover()
        popover.behavior = .transient
        let storyBoard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
        let identifier = NSStoryboard.SceneIdentifier("PopoverAnimationVC")
        guard let vc = storyBoard.instantiateController(withIdentifier: identifier) as? PopoverAnimationVC else { return }
        popover.contentViewController = vc
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: NSRectEdge.maxX)
    }
}

class PopoverAnimationVC: NSViewController {

    @IBOutlet weak var imageView: NSImageView! {
        didSet {
            imageView.canDrawSubviewsIntoLayer = true
            imageView.imageScaling = .scaleNone
            imageView.animates = true
            imageView.image = NSImage(named: NSImage.Name(rawValue: "example"))
        }
    }
}
