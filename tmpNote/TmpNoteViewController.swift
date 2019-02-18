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

    enum Mode: Int {
        case text
        case sketch
    }
    
    static let kFontSizeKey = "FontSize"
    static let kFontSizes = [8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 36, 48, 72]
    static var defaultFontSize: Int {
        return kFontSizes[4]
    }

    static let kPreviousSessionTextKey = "PreviousSessionText"
    static let kPreviousSessionModeKey = "PreviousMode"
    
    var drawingScene: DrawingScene?
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
            lockButton.image = isLocked ? NSImage(named: "NSLockLockedTemplate") : NSImage(named: "NSLockUnlockedTemplate")
            lockButton.toolTip = isLocked ? "Do Not Hide on Deactivate" : "Hide on Deactivate"
        }
    }
    
    var lines = [SKShapeNode]()
    var currentMode: Mode = .text {
        didSet {
            let icon = currentMode == .sketch ? NSImage(named: "draw_filled") : NSImage(named: "draw")
            drawButton.state = currentMode == .sketch ? .on : .off
            drawButton.image = icon
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.

        shareButton.sendAction(on: .leftMouseDown)
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        let prevModeInt = UserDefaults.standard.integer(forKey: TmpNoteViewController.kPreviousSessionModeKey)
        if let mode = Mode(rawValue: prevModeInt) {
            switch mode {
            case .text:
                textView?.window?.makeKeyAndOrderFront(self)
                removeDrawScene()
            case .sketch:
                createDrawScene()
            }
        }
    }
    
    override func viewWillDisappear() {
        drawingScene?.removeFromParent()
        skview?.removeFromSuperview()
        
        textareaScrollView.isHidden = false
        drawingView.isHidden = true

        super.viewWillDisappear()
    }
    
    func createDrawScene() {
        skview = SKView(frame: drawingView.bounds)
        drawingView.addSubview(skview!)
        drawingScene = SKScene(fileNamed: "DrawingScene") as? DrawingScene
        drawingScene?.mainController = self
        drawingScene?.contentDidChangeCallback = contentDidChange
        skview?.presentScene(drawingScene)
        
        drawingScene?.load()
        
        skview?.backgroundColor = .clear
        skview?.allowsTransparency = true
        drawingView.backgroundColor = .clear
        drawingScene?.backgroundColor = .clear
        
        textareaScrollView.isHidden = true
        drawingView.isHidden = false
        
        currentMode = .sketch
    }
    
    func removeDrawScene() {
        drawingScene?.removeFromParent()
        skview?.removeFromSuperview()
        
        textareaScrollView.isHidden = false
        drawingView.isHidden = true
        
        currentMode = .text
    }
    
    @IBAction func toggleDrawingMode(_ sender: Any) {
        save()
        
        switch currentMode {
            case .text:
                createDrawScene()
            case .sketch:
                removeDrawScene()
        }
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
        textView.string = TmpNoteViewController.loadText()
        textView.checkTextInDocument(nil)

        loadSketch()
    }
    
    func loadSketch() {
        lines = TmpNoteViewController.loadSketch()
        
        contentDidChange()
    }
    
    static func loadText() -> String {
        var text = ""
        
        if let savedText = UserDefaults.standard.string(forKey: TmpNoteViewController.kPreviousSessionTextKey)  {
            text = savedText
        }
        
        return text
    }
    
    static func loadSketch() -> [SKShapeNode] {
        var lines = [SKShapeNode]()
        
        if let encodedLines = UserDefaults.standard.value(forKey: DrawingScene.saveKey) as? [Data] {
            for data in encodedLines {
                if let bp = NSKeyedUnarchiver.unarchiveObject(with: data) as? NSBezierPath {
                    let path = bp.cgPath
                    let newLine = SKShapeNode(path: path)
                    newLine.strokeColor = .textColor
                    lines.append(newLine)
                }
            }
        }
        
        return lines
    }

    @IBAction func lockAction(_ sender: Any) {
        let isLocked = UserDefaults.standard.bool(forKey: "locked")
        UserDefaults.standard.set(!isLocked, forKey: "locked")
        lockButton.image = isLocked ? NSImage(named: "NSLockUnlockedTemplate") : NSImage(named: "NSLockLockedTemplate")
        lockButton.toolTip = isLocked ? "Do Not Hide on Deactivate" : "Hide on Deactivate"
    }
    
    func save() {
        UserDefaults.standard.set(textView.string, forKey: TmpNoteViewController.kPreviousSessionTextKey)
        UserDefaults.standard.set(currentMode.rawValue, forKey: TmpNoteViewController.kPreviousSessionModeKey)
        
        saveSketch()
    }
    
    func saveSketch() {
        let paths:[CGPath] = lines.compactMap { $0.path }
        
        var encodedLines = [Data]()
        for path in paths {
            let bp = NSBezierPath()
            
            let points:[CGPoint] = path.getPathElementsPoints()
            if points.count > 0 {
                
                bp.move(to: points.first!)
                for i in 1..<points.count {
                    bp.line(to: points[i])
                }
                
                let arch = NSKeyedArchiver.archivedData(withRootObject: bp)
                encodedLines.append(arch)
            }
        }
        
        UserDefaults.standard.set(encodedLines, forKey: DrawingScene.saveKey)
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

    @IBAction func changeFontSize(_ sender: NSSegmentedControl) {
        if sender.indexOfSelectedItem == 0 {
            decreaseFontSize()
        }
        else {
            increaseFontSize()
        }
    }
    
    func decreaseFontSize() {
        let fontSize = UserDefaults.standard.object(forKey: TmpNoteViewController.kFontSizeKey) as? Int ?? TmpNoteViewController.defaultFontSize
        
        guard let currentFontIndex = TmpNoteViewController.kFontSizes.index(of: fontSize) else { return }
        let nextFontSize = currentFontIndex-1 > 0 ? TmpNoteViewController.kFontSizes[currentFontIndex-1] : TmpNoteViewController.kFontSizes.first

        
        if let newFontSize = nextFontSize {
            UserDefaults.standard.set(newFontSize, forKey: TmpNoteViewController.kFontSizeKey)
            self.setFontSize(size: CGFloat(newFontSize))
        }
    }
    
    func increaseFontSize() {
        let fontSize = UserDefaults.standard.object(forKey: TmpNoteViewController.kFontSizeKey) as? Int ?? TmpNoteViewController.defaultFontSize
        
        guard let currentFontIndex = TmpNoteViewController.kFontSizes.index(of: fontSize) else { return }
        let nextFontSize = currentFontIndex+1 < TmpNoteViewController.kFontSizes.count ? TmpNoteViewController.kFontSizes[currentFontIndex+1] : TmpNoteViewController.kFontSizes.last
        
        if let newFontSize = nextFontSize {
            UserDefaults.standard.set(newFontSize, forKey: TmpNoteViewController.kFontSizeKey)
            self.setFontSize(size: CGFloat(newFontSize))
        }
    }
    
    @IBAction func clearAction(_ sender: Any) {
        
        if drawingView.isHidden {
            textView.string = ""
            save()
        }
        else {
            drawingScene?.clear()
        }
        
        contentDidChange()
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
        contentDidChange()
    }
    
    func contentDidChange() {
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        let isTextContent = textView.string.isEmpty == false
        let isSketchContent = lines.count > 0
        appDelegate.toggleMenuIcon(fill: (isTextContent || isSketchContent))
    }
}

// MARK: NSSharingServicePickerDelegate
extension TmpNoteViewController: NSSharingServicePickerDelegate {
    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, sharingServicesForItems items: [Any], proposedSharingServices proposedServices: [NSSharingService]) -> [NSSharingService] {
        
        guard let image = NSImage(named: "copy") else {
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
        
        let storyBoard = NSStoryboard(name: "Main", bundle: nil)
        let identifier = "TmpNoteViewController"
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
