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

    static let kPreviousSessionModeKey = "PreviousMode"
    
    var drawingScene: DrawingScene?
    var skview: SKView?
    
    var tmpLockMode = false
    var currentViewIndex: Int = 1
    
    @IBOutlet weak var hidableHeaderView: NSVisualEffectView!
    @IBOutlet weak var headerView: HeaderView! {
        didSet {
            headerView.onMouseExitedClosure = { [weak self] in
                DispatchQueue.main.async {
                      NSAnimationContext.runAnimationGroup({ context in
                          context.duration = 0.15
                        self?.hidableHeaderView.alphaValue = 0
                      }, completionHandler: nil)
                }
            }
            headerView.onMouseEnteredClosure = { [weak self] in
                DispatchQueue.main.async {
                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = 0.15
                      self?.hidableHeaderView.alphaValue = 1
                    }, completionHandler: nil)
                }
            }

        }
    }

    @IBOutlet weak var viewButtons: NSStackView!
    @IBOutlet weak var drawButton: NSButton!
    @IBOutlet weak var shareButton: NSButton!
    @IBOutlet weak var textareaScrollView: NSScrollView!
    @IBOutlet weak var drawingView: NSView!
    @IBOutlet var appMenu: NSMenu!
    @IBOutlet var textView: NSTextView! {
        didSet {
            textView.delegate = self
            DispatchQueue.main.async { [weak self] in
                self?.setupTextView()
                self?.loadPreviousText()
            }
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
        setupViewButtons()
    }
    
    func removeDrawScene() {
        drawingScene?.removeFromParent()
        skview?.removeFromSuperview()
        
        textareaScrollView.isHidden = false
        drawingView.isHidden = true
        
        currentMode = .text
        setupViewButtons()
    }
    
    func setupViewButtons() {
        let enabled = currentMode != .sketch
        let selectedTag = currentViewIndex
        
        if let buttons = viewButtons.arrangedSubviews as? [CustomRadioButton] {
            buttons.forEach {
                $0.isEnabled = enabled
                $0.toggleState(newState: $0.tag == selectedTag ? .on : .off)
            }
        }
    }
    
    @IBAction func changeView(_ sender: NSButton) {
        save()
        currentViewIndex = sender.tag
        loadPreviousText()
        
        setupViewButtons()
    }

    @IBAction func viewDidChange(_ sender: NSPopUpButton) {
        guard let selectedItem = sender.selectedItem else { return }
        
        if selectedItem.tag == -1 {
            DispatchQueue.main.async { [weak self] in
                self?.save()
            }
            
            createDrawScene()
        }
        else {
            removeDrawScene()
        }
    }
    
    @IBAction func toggleDrawingMode(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.save()
        }
        
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
    
    var directoryObserver: DirectoryObserver?
    
    func loadPreviousText() {
        loadSubstitutions()
        
        TmpNoteViewController.loadText(viewIndex: currentViewIndex) { [weak self] (savedText) in
            self?.textView.string = savedText
            self?.textView.checkTextInDocument(nil)
        }

        TmpNoteViewController.loadSketch() { [weak self] savedLines in
            self?.lines = savedLines
            self?.contentDidChange()
            self?.drawingScene?.load()
        }
        
        setupViewButtons()
    }
    
    func loadSubstitutions() {
        textView.isAutomaticDashSubstitutionEnabled = UserDefaults.standard.object(forKey: "SmartDashes") != nil ? UserDefaults.standard.bool(forKey: "SmartDashes") : true
        textView.isAutomaticSpellingCorrectionEnabled = UserDefaults.standard.object(forKey: "SmartSpelling") != nil ? UserDefaults.standard.bool(forKey: "SmartSpelling") : true
        textView.isAutomaticTextReplacementEnabled = UserDefaults.standard.object(forKey: "SmartTextReplacing") != nil ? UserDefaults.standard.bool(forKey: "SmartTextReplacing") : true
        textView.isAutomaticDataDetectionEnabled = UserDefaults.standard.object(forKey: "SmartDataDetection") != nil ? UserDefaults.standard.bool(forKey: "SmartDataDetection") : true
        textView.isAutomaticQuoteSubstitutionEnabled = UserDefaults.standard.object(forKey: "SmartQuotes") != nil ? UserDefaults.standard.bool(forKey: "SmartQuotes") : true
        textView.isAutomaticLinkDetectionEnabled = UserDefaults.standard.object(forKey: "SmartLinks") != nil ? UserDefaults.standard.bool(forKey: "SmartLinks") : true
    }

    @IBAction func lockAction(_ sender: Any) {
        let isLocked = UserDefaults.standard.bool(forKey: "locked")
        UserDefaults.standard.set(!isLocked, forKey: "locked")
        lockButton.image = isLocked ? NSImage(named: "NSLockUnlockedTemplate") : NSImage(named: "NSLockLockedTemplate")
        lockButton.toolTip = isLocked ? "Do Not Hide on Deactivate" : "Hide on Deactivate"
    }
    
    func save() {
        TmpNoteViewController.saveTextIfChanged(note: textView.string, viewIndex: currentViewIndex, completion: nil)
        TmpNoteViewController.saveSketchIfChanged(lines: lines, completion: nil)

        UserDefaults.standard.set(currentMode.rawValue, forKey: TmpNoteViewController.kPreviousSessionModeKey)
        
        saveSubstitutions()
    }
    
    func saveSubstitutions() {
        let dashes = textView.isAutomaticDashSubstitutionEnabled
        let spelling = textView.isAutomaticSpellingCorrectionEnabled
        let textReplacing = textView.isAutomaticTextReplacementEnabled
        let dataDetection = textView.isAutomaticDataDetectionEnabled
        let quotes = textView.isAutomaticQuoteSubstitutionEnabled
        let links = textView.isAutomaticLinkDetectionEnabled
        
        UserDefaults.standard.set(dashes, forKey: "SmartDashes")
        UserDefaults.standard.set(spelling, forKey: "SmartSpelling")
        UserDefaults.standard.set(textReplacing, forKey: "SmartTextReplacing")
        UserDefaults.standard.set(dataDetection, forKey: "SmartDataDetection")
        UserDefaults.standard.set(quotes, forKey: "SmartQuotes")
        UserDefaults.standard.set(links, forKey: "SmartLinks")
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
    
    @IBAction func increaseFontSize(_ sender: Any) {
        increaseFontSize()
    }
    
    @IBAction func decreaseFontSize(_ sender: Any) {
        decreaseFontSize()
    }
    
    func decreaseFontSize() {
        let fontSize = UserDefaults.standard.object(forKey: TmpNoteViewController.kFontSizeKey) as? Int ?? TmpNoteViewController.defaultFontSize
        
        guard let currentFontIndex = TmpNoteViewController.kFontSizes.firstIndex(of: fontSize) else { return }
        let nextFontSize = currentFontIndex-1 > 0 ? TmpNoteViewController.kFontSizes[currentFontIndex-1] : TmpNoteViewController.kFontSizes.first

        
        if let newFontSize = nextFontSize {
            UserDefaults.standard.set(newFontSize, forKey: TmpNoteViewController.kFontSizeKey)
            self.setFontSize(size: CGFloat(newFontSize))
        }
    }
    
    func increaseFontSize() {
        let fontSize = UserDefaults.standard.object(forKey: TmpNoteViewController.kFontSizeKey) as? Int ?? TmpNoteViewController.defaultFontSize
        
        guard let currentFontIndex = TmpNoteViewController.kFontSizes.firstIndex(of: fontSize) else { return }
        let nextFontSize = currentFontIndex+1 < TmpNoteViewController.kFontSizes.count ? TmpNoteViewController.kFontSizes[currentFontIndex+1] : TmpNoteViewController.kFontSizes.last
        
        if let newFontSize = nextFontSize {
            UserDefaults.standard.set(newFontSize, forKey: TmpNoteViewController.kFontSizeKey)
            self.setFontSize(size: CGFloat(newFontSize))
        }
    }
    
    func deleteDialog(question: String, text: String) -> NSAlert {
        
        // Prevent popup from hiding while the dialog is visible
        tmpLockMode = UserDefaults.standard.bool(forKey: "locked")
        UserDefaults.standard.set(true, forKey: "locked")

        
        let alert = NSAlert()
        alert.messageText = question
        alert.informativeText = text
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        return alert
    }
    
    @IBAction func clearAction(_ sender: Any) {
        
        var message: (String, String)
        switch currentMode {
            case .text:
                message = ("Delete the note?", "Are you sure you would like to delete the note?")
            case .sketch:
                message = ("Delete the drawing?", "Are you sure you would like to delete the drawing?")
        }
        
        deleteDialog(question: message.0, text: message.1).beginSheetModal(for: self.view.window!, completionHandler: { [weak self] (modalResponse) -> Void in
            guard let strongSelf = self else { return }
            
            if let lock = self?.tmpLockMode {
                UserDefaults.standard.set(lock, forKey: "locked")
            }
            
            if modalResponse == .alertFirstButtonReturn {
                
                if let mode = self?.currentMode {
                    switch mode {
                        case .text:
                            if let textLength = strongSelf.textView.textStorage?.length {
                                strongSelf.textView.insertText("", replacementRange: NSRange(location: 0, length: textLength))
                                self?.save()
                            }

                        case .sketch:
                            self?.drawingScene?.clear()
                    }
                    
                    self?.contentDidChange()
                }
            }
        })
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

//MARK: Storage
extension TmpNoteViewController {
    
    static func localFileURL(name: String, extensionStr: String) -> URL? {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths.first?.appendingPathComponent(name).appendingPathExtension(extensionStr)
    }

    static func remoteFileURL(name: String, extensionStr: String) -> URL? {
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        return appDelegate.containerUrl?.appendingPathComponent(name).appendingPathExtension(extensionStr)
    }
    
    static func defaultTextFileURL(viewIndex: Int) -> URL? {
        let fileName = "defaultContainer_\(viewIndex)"
        let fileExtension = "txt"
        
        if UserDefaults.standard.bool(forKey: "SynchronizeContent") == true {
            if let url = TmpNoteViewController.remoteFileURL(name: fileName, extensionStr: fileExtension) {
                return url
            }
        }
        
        return TmpNoteViewController.localFileURL(name: fileName, extensionStr: fileExtension)
    }

    static var defaultSketchFileURL: URL? {
        let fileName = "defaultSketch"
        let fileExtension = "tmpSketch"
        
        if UserDefaults.standard.bool(forKey: "SynchronizeContent") == true {
            if let url = TmpNoteViewController.remoteFileURL(name: fileName, extensionStr: fileExtension) {
                return url
            }
        }
        
        return TmpNoteViewController.localFileURL(name: fileName, extensionStr: fileExtension)
    }
    
    static func saveTextIfChanged(note: String, viewIndex: Int, completion: ((Bool)->Void)?) {
        var result = false
        
        defer {
            completion?(result)
        }

        // Check if text has been changed
        let savedText = loadText(viewIndex: viewIndex)
        if note == savedText {
            return
        }
        
        if let url = defaultTextFileURL(viewIndex: viewIndex) {
            do {
                try note.write(to: url, atomically: true, encoding: .utf8)
                result = true
            } catch {
                debugPrint(error.localizedDescription)
            }
        }
    }
    
    static func loadText(viewIndex: Int) -> String {
        var text = ""

        if let url = defaultTextFileURL(viewIndex: viewIndex), let txt = try? String(contentsOf: url) {
            text = txt
        }
        
        return text
    }
    
    static func loadText(viewIndex: Int, completion: (String)->Void) {
        let savedText = loadText(viewIndex: viewIndex)
        completion(savedText)
    }
    
    static func saveSketchIfChanged(lines: [SKShapeNode], completion: ((Bool)->Void)?) {
        var result = false
        
        defer {
            completion?(result)
        }
        
        let paths:[CGPath] = lines.compactMap { $0.path }

        let savedPaths = loadSketch().compactMap { $0.path }
        if paths == savedPaths {
            return
        }
        
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

        if let url = TmpNoteViewController.defaultSketchFileURL {
            result = NSKeyedArchiver.archiveRootObject(encodedLines, toFile: url.path)
        }
    }

    static private  func loadSketch() -> [SKShapeNode] {
        var lines = [SKShapeNode]()

        if let url = TmpNoteViewController.defaultSketchFileURL {
            if let encodedLines = NSKeyedUnarchiver.unarchiveObject(withFile: url.path) as? [Data] {
                for data in encodedLines {
                    if let bp = NSKeyedUnarchiver.unarchiveObject(with: data) as? NSBezierPath {
                        let path = bp.cgPath
                        let newLine = SKShapeNode(path: path)
                        newLine.strokeColor = .textColor
                        lines.append(newLine)
                    }
                }
            }
        }

        return lines
    }
    static func loadSketch(completion: ([SKShapeNode])->Void) {
        let lines = loadSketch()
        completion(lines)
    }
}

//MARK: Storage Migration
extension TmpNoteViewController {
    
    static private func migrateText() {
        let textUserDefaultsKey = "PreviousSessionText"
        
        if let prevText = UserDefaults.standard.string(forKey: textUserDefaultsKey) {
            TmpNoteViewController.saveTextIfChanged(note: prevText, viewIndex: 1) { (saved) in
                if saved == true {
                    //Nulify old text storage
                    UserDefaults.standard.removeObject(forKey: textUserDefaultsKey)
                }
            }
        }
    }
    
    static private func migrateSketch() {
        let sketchUserDefaultsKey = "PreviousSessionSketch"
        
        if let encodedLines = UserDefaults.standard.value(forKey: sketchUserDefaultsKey) as? [Data] {
            var lines = [SKShapeNode]()
            for data in encodedLines {
                if let bp = NSKeyedUnarchiver.unarchiveObject(with: data) as? NSBezierPath {
                    let path = bp.cgPath
                    let newLine = SKShapeNode(path: path)
                    newLine.strokeColor = .textColor
                    lines.append(newLine)
                }
            }
            
            TmpNoteViewController.saveSketchIfChanged(lines: lines) { (saved) in
                if saved == true {
                    //Nulify old sketch storage
                    UserDefaults.standard.removeObject(forKey: sketchUserDefaultsKey)
                }
            }
        }
    }
    
    static public func migrate() {
        migrateText()
        migrateSketch()
    }
}

class DirectoryObserver {

    private let fileDescriptor: CInt
    private let source: DispatchSourceProtocol

    deinit {

      self.source.cancel()
      close(fileDescriptor)
    }

    init(URL: URL, block: @escaping ()->Void) {

      self.fileDescriptor = open(URL.path, O_EVTONLY)
        self.source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: self.fileDescriptor, eventMask: .all, queue: DispatchQueue.global())
      self.source.setEventHandler {
          block()
      }
      self.source.resume()
  }

}

class CustomRadioButton: NSButton {

    func toggleState(newState: StateValue) {
        self.state = newState
        let imageName = self.state == .on ? "page_indicator_active" : "page_indicator"
        self.image = NSImage(named: imageName)
    }
}
