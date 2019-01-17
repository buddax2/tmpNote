//
//  TmpNoteViewController.swift
//  tmpNote
//
//  Created by BUDDAx2 on 9/24/17.
//  Copyright © 2017 BUDDAx2. All rights reserved.
//

import Cocoa
import SpriteKit


class TmpNoteViewController: NSViewController, NSTextViewDelegate {

    static let kFontSizeKey = "FontSize"
    static let kFontSizes = [8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 36, 48, 72]
    static var defaultFontSize: Int {
        return kFontSizes[4]
    }

    static let kPreviousSessionTextKey = "PreviousSessionText"

    var drawingScene: DrawingScene? {
        didSet {
            drawingScene?.load()
        }
    }
    var skview: SKView?
    
    @IBOutlet weak var hidableHeaderView: NSVisualEffectView!
    @IBOutlet weak var headerView: HeaderView! {
        didSet {
            headerView.onMouseExitedClosure = { [weak self] in
                DispatchQueue.main.async {
                    self?.hidableHeaderView.isHidden = true
                }
            }
            headerView.onMouseEnteredClosure = { [weak self] in
                DispatchQueue.main.async {
                    self?.hidableHeaderView.isHidden = false
                }
            }

        }
    }
    @IBOutlet weak var drawButton: NSButton!
    @IBOutlet weak var shareButton: NSButton!
    @IBOutlet weak var textareaScrollView: NSScrollView!
    @IBOutlet weak var drawingView: NSView!
    @IBOutlet var appMenu: NSMenu!
    @IBOutlet var textView: NSTextView! {
        didSet {
            textView.delegate = self
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

        skview = SKView(frame: drawingView.bounds)
        drawingView.addSubview(skview!)
        drawingScene = SKScene(fileNamed: "DrawingScene") as? DrawingScene
        skview?.presentScene(drawingScene)
        
        skview?.backgroundColor = .clear
        skview?.allowsTransparency = true
        drawingView.backgroundColor = .clear
        drawingScene?.backgroundColor = .clear
        
        shareButton.sendAction(on: .leftMouseDown)
    }
    
    func willAppear() {
        // make textview focused
        textView?.window?.makeKeyAndOrderFront(self)
    }
    
    @IBAction func toggleDrawingMode(_ sender: Any) {
        textareaScrollView.isHidden.toggle()
        drawingView.isHidden.toggle()
        
        drawButton.state = drawingView.isHidden == false ? .on : .off
    }
    
    func copyContent() {
        if drawingView.isHidden == false {
            
            if let image = imageFromScene() {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects([image])
            }
            
            return
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
        pasteboard.setString(textView.string, forType: NSPasteboard.PasteboardType.string)
    }
    
    func imageFromScene() -> NSImage? {
        var isDarkTheme = false
        if #available(OSX 10.14, *) {
            isDarkTheme = NSAppearance.current.name == NSAppearance.Name.darkAqua || NSAppearance.current.name == NSAppearance.Name.vibrantDark
        } else {
            isDarkTheme = NSAppearance.current.name == NSAppearance.Name.vibrantDark
        }
        drawingScene?.backgroundColor = isDarkTheme ? .darkGray : .white
        let texture = skview?.texture(from: drawingScene!)
        drawingScene?.backgroundColor = .clear

        if let texture = texture {
            let img2 = texture.cgImage()
            let image = NSImage(cgImage: img2, size: drawingScene!.size)

            return image
        }

        return nil
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
        drawingScene?.save()
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
        
        if drawingView.isHidden {
            textView.string = ""
            saveText()
        }
        else {
            drawingScene?.clear()
        }
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
        var sharedItems = [Any]()
        
        if drawingView.isHidden == false {
            if let image = imageFromScene() {
                sharedItems = [image]
            }
        }
        else {
            sharedItems = [textView.string];
        }
        
        let servicePicker = NSSharingServicePicker(items: sharedItems)
        servicePicker.delegate = self
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
    
    func textDidChange(_ notification: Notification) {
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.toggleMenuIcon(fill: textView.string.isEmpty == false)
    }
}

// MARK: NSSharingServicePickerDelegate
extension TmpNoteViewController: NSSharingServicePickerDelegate {
    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, sharingServicesForItems items: [Any], proposedSharingServices proposedServices: [NSSharingService]) -> [NSSharingService] {
        
        guard let image = NSImage(named: NSImage.Name(rawValue: "copy")) else {
            return proposedServices
        }
        
        var share = proposedServices
        let plainText = NSSharingService(title: "Copy", image: image, alternateImage: image, handler: {
            self.copyContent()
        })
        share.insert(plainText, at: 0)
        
        return share
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
        
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.toggleMenuIcon(fill: textView.string.isEmpty == false)
    }
}
