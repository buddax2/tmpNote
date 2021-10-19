//
//  TmpNoteViewController.swift
//  tmpNote
//
//  Created by BUDDAx2 on 9/24/17.
//  Copyright © 2017 BUDDAx2. All rights reserved.
//

import Cocoa
import SpriteKit
import Carbon.HIToolbox
import SwiftyMarkdown
import Combine

class TmpNoteViewController: NSViewController, NSTextViewDelegate {
    
    static let kFontSizeKey = "FontSize"
    static let kFontSizes = [8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 36, 48, 72]
    static var defaultFontSize: Int {
        return kFontSizes[4]
    }
    
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

    @IBOutlet weak var pageTouchBarButton: NSSegmentedControl!
    @IBOutlet weak var contentTouchBarButton: NSSegmentedControl!
    @IBOutlet weak var lockTouchBarButton: NSButton!
    @IBOutlet weak var viewButtons: NSStackView!
    @IBOutlet weak var shareButton: NSButton!
    @IBOutlet weak var textareaScrollView: NSScrollView!
    @IBOutlet weak var drawingView: NSView!
    @IBOutlet weak var contentModeButton: NSSegmentedControl!
    @IBOutlet var appMenu: NSMenu!
    @IBOutlet weak var clearButton: NSButton!
    @IBOutlet var textView: NoteTextView! {
        didSet {
            textView.delegate = self
//            textView.storageDataSource = self
            DispatchQueue.main.async { [weak self] in
                self?.setupTextView()
                
                DatasourceController.shared.load()
//                self?.load()
            }
        }
    }
    @IBOutlet weak var lockButton: NSButton! {
        didSet {
            let isLocked = UserDefaults.standard.bool(forKey: "locked")
            lockButton.image = isLocked ? NSImage(named: "NSLockLockedTemplate") : NSImage(named: "NSLockUnlockedTemplate")
            lockButton.toolTip = isLocked ? "Do Not Hide on Deactivate ⌘L" : "Hide on Deactivate ⌘L"
        }
    }
    
    var lines = [SKShapeNode]()
    var currentMode: Mode = .text {
        didSet {
            let icon = currentMode == .sketch ? NSImage(named: "draw_filled") : NSImage(named: "draw_empty")
            contentModeButton.setImage(icon, forSegment: Mode.sketch.rawValue)
            syncUI()
        }
    }
    
    func syncUI() {
        contentTouchBarButton.selectedSegment = currentMode.rawValue
        contentModeButton.selectedSegment = currentMode.rawValue
        
        switch currentMode {
        case .text:
            removeDrawScene()
            showPlainText()
        case .markdown:
            removeDrawScene()
            showMarkdown()
        case .sketch:
            createDrawScene()
        }
        
        clearButton.isEnabled = currentMode == .text || currentMode == .sketch
    }
    
    var rawText: String = ""
    var subscribers = Set<AnyCancellable>()
    
    
    func showMarkdown() {
        textView.isEditable = false
        
        let fontSize = UserDefaults.standard.value(forKey: TmpNoteViewController.kFontSizeKey) as? Int ?? TmpNoteViewController.defaultFontSize
        let color: NSColor = currentAppearanceIsLight ? .black : .white
        
        let md = markdown(text: rawText, baseFontSize: CGFloat(fontSize), color: color)
        textView.textStorage?.setAttributedString(md.attributedString())
    }
    
    func markdown(text: String, baseFontSize: CGFloat, color: NSColor) -> SwiftyMarkdown {
        let md = SwiftyMarkdown(string: rawText)
        md.setFontColorForAllStyles(with: color)
        md.setFontSizeForAllStyles(with: baseFontSize)
        
        md.h1.fontSize = baseFontSize + 10
        md.h1.fontStyle = .bold

        md.h2.fontSize = baseFontSize + 8
        md.h2.fontStyle = .bold

        md.h3.fontSize = baseFontSize + 4
        md.h3.fontStyle = .bold

        md.h4.fontSize = baseFontSize
        md.h4.fontStyle = .bold

        md.h5.fontSize = baseFontSize - 2
        md.h5.fontStyle = .bold

        md.h6.fontSize = baseFontSize - 4
        md.h6.fontStyle = .bold

        md.blockquotes.fontSize = baseFontSize - 2
        md.blockquotes.color = .gray

        md.code.color = .red

        return md
    }
    
    func showPlainText() {
        textView.string = rawText
        textView.isEditable = true
        setupTextView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.

        listenToInterfaceChangesNotification()
        
        shareButton.sendAction(on: .leftMouseDown)
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        DatasourceController.shared.$content.receive(on: DispatchQueue.main)
            .sink { _ in
            
            } receiveValue: { [weak self] newContent in
                self?.rawText = newContent
                self?.showPlainText()
            }
            .store(in: &subscribers)

        let prevModeInt = UserDefaults.standard.integer(forKey: DatasourceKey.previousSessionModeKey.rawValue)
        contentModeButton.setSelected(true, forSegment: prevModeInt)
        if let mode = Mode(rawValue: prevModeInt) {
            currentMode = mode
        }
    }
    
    override func viewWillDisappear() {
        drawingScene?.removeFromParent()
        skview?.removeFromSuperview()
        
        textareaScrollView.isHidden = false
        drawingView.isHidden = true

        super.viewWillDisappear()
    }

    var appearanceChangeObservation: NSKeyValueObservation?
    
    func listenToInterfaceChangesNotification() {
        appearanceChangeObservation = self.view.observe(\.effectiveAppearance) { [weak self] _, _  in
            guard let strongSelf = self else { return }
            if strongSelf.currentMode == .markdown {
                strongSelf.showMarkdown()
            }
        }
    }
    
    var currentAppearanceIsLight: Bool {
        let isLight: Bool
        if #available(OSX 10.14, *) {
            isLight = view.effectiveAppearance.name != .darkAqua && view.effectiveAppearance.name != .vibrantDark
        } else {
            // Fallback on earlier versions
            isLight = NSAppearance.current.name != .vibrantDark
        }

        return isLight
    }

    @IBAction func contentModeDidChange(_ sender: NSSegmentedControl) {
        guard let contentMode = Mode(rawValue: sender.selectedSegment) else { return }
        if currentMode != contentMode {
            currentMode = contentMode
        }
    }
    
    @IBAction func pageTouchBarDidChange(_ sender: NSSegmentedControl) {
        DatasourceController.shared.save()
        currentViewIndex = sender.selectedSegment + 1
        DatasourceController.shared.load()

        
        setupViewButtons()
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
        
        setupViewButtons()
    }
    
    func removeDrawScene() {
        drawingScene?.removeFromParent()
        skview?.removeFromSuperview()
        
        textareaScrollView.isHidden = false
        drawingView.isHidden = true
        
        setupViewButtons()
    }
    
    func setupViewButtons() {
        let enabled = currentMode != .sketch
        let selectedTag = currentViewIndex
        
        pageTouchBarButton.selectedSegment = selectedTag - 1
        
        if let buttons = viewButtons.arrangedSubviews as? [CustomRadioButton] {
            buttons.forEach {
                $0.isEnabled = enabled
                $0.toggleState(newState: $0.tag == selectedTag ? .on : .off)
            }
        }
    }
    
    @IBAction func changeView(_ sender: NSButton) {
        DatasourceController.shared.save()
        currentViewIndex = sender.tag
        DatasourceController.shared.load()

        setupViewButtons()
    }

    @IBAction func viewDidChange(_ sender: NSPopUpButton) {
        guard let selectedItem = sender.selectedItem else { return }
        
        if selectedItem.tag == -1 {
            DatasourceController.shared.save()
            
            createDrawScene()
        }
        else {
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
        
        if currentMode == .markdown {
            showMarkdown()
        }
    }
    
    func loadSubstitutions() {
        textView.isAutomaticDashSubstitutionEnabled = UserDefaults.standard.object(forKey: "SmartDashes") != nil ? UserDefaults.standard.bool(forKey: "SmartDashes") : true
        textView.isAutomaticSpellingCorrectionEnabled = UserDefaults.standard.object(forKey: "SmartSpelling") != nil ? UserDefaults.standard.bool(forKey: "SmartSpelling") : true
        textView.isAutomaticTextReplacementEnabled = UserDefaults.standard.object(forKey: "SmartTextReplacing") != nil ? UserDefaults.standard.bool(forKey: "SmartTextReplacing") : true
        textView.isAutomaticDataDetectionEnabled = UserDefaults.standard.object(forKey: "SmartDataDetection") != nil ? UserDefaults.standard.bool(forKey: "SmartDataDetection") : true
        textView.isAutomaticQuoteSubstitutionEnabled = UserDefaults.standard.object(forKey: "SmartQuotes") != nil ? UserDefaults.standard.bool(forKey: "SmartQuotes") : true
        textView.isAutomaticLinkDetectionEnabled = UserDefaults.standard.object(forKey: "SmartLinks") != nil ? UserDefaults.standard.bool(forKey: "SmartLinks") : true
        textView.isGrammarCheckingEnabled = UserDefaults.standard.object(forKey: "GrammarChecking") != nil ? UserDefaults.standard.bool(forKey: "GrammarChecking") : true
        textView.isContinuousSpellCheckingEnabled = UserDefaults.standard.object(forKey: "SpellChecking") != nil ? UserDefaults.standard.bool(forKey: "SpellChecking") : true
    }

    @IBAction func lockAction(_ sender: Any) {
        let isLocked = UserDefaults.standard.bool(forKey: "locked")
        UserDefaults.standard.set(!isLocked, forKey: "locked")
        lockButton.image = isLocked ? NSImage(named: "NSLockUnlockedTemplate") : NSImage(named: "NSLockLockedTemplate")
        lockButton.toolTip = isLocked ? "Do Not Hide on Deactivate" : "Hide on Deactivate"
        lockTouchBarButton.image = isLocked ? NSImage(named: "NSLockUnlockedTemplate") : NSImage(named: "NSLockLockedTemplate")
        
        
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.changeLockMode(locked: !isLocked)
    }
    
    @IBAction func toggleWindowState(_ sender: Any) {
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.toggleWindowState()
    }
    
    func saveSubstitutions() {
        let dashes = textView.isAutomaticDashSubstitutionEnabled
        let spelling = textView.isAutomaticSpellingCorrectionEnabled
        let textReplacing = textView.isAutomaticTextReplacementEnabled
        let dataDetection = textView.isAutomaticDataDetectionEnabled
        let quotes = textView.isAutomaticQuoteSubstitutionEnabled
        let links = textView.isAutomaticLinkDetectionEnabled
        let grammar = textView.isGrammarCheckingEnabled
        let spellChecking = textView.isContinuousSpellCheckingEnabled

        
        UserDefaults.standard.set(dashes, forKey: "SmartDashes")
        UserDefaults.standard.set(spelling, forKey: "SmartSpelling")
        UserDefaults.standard.set(textReplacing, forKey: "SmartTextReplacing")
        UserDefaults.standard.set(dataDetection, forKey: "SmartDataDetection")
        UserDefaults.standard.set(quotes, forKey: "SmartQuotes")
        UserDefaults.standard.set(links, forKey: "SmartLinks")
        UserDefaults.standard.set(grammar, forKey: "GrammarChecking")
        UserDefaults.standard.set(spellChecking, forKey: "SpellChecking")
    }
    
    ///Close popover if Esc key is pressed
    override func cancelOperation(_ sender: Any?) {
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.close()
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
            case .text, .markdown:
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
                        case .text, .markdown:
                            if let textLength = strongSelf.textView.textStorage?.length {
                                strongSelf.textView.insertText("", replacementRange: NSRange(location: 0, length: textLength))
                                DatasourceController.shared.save()
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
        
        switch currentMode {
            case .text:
                sharedItems = [textView.string];
            case .sketch:
                if let image = imageFromScene() {
                    sharedItems = [image]
                }
            case .markdown:
                sharedItems = [textView.attributedString()];
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
        if currentMode == .text {
            rawText = textView.string
        }
        let isTextContent = rawText.isEmpty == false
        let isSketchContent = lines.count > 0
        
        DatasourceController.shared.content = rawText
        DatasourceController.shared.currentViewIndex = currentViewIndex
        DatasourceController.shared.lines = lines

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

//MARK: Storage Migration
//extension TmpNoteViewController {
//
//    static private func migrateText() {
//        let textUserDefaultsKey = "PreviousSessionText"
//
//        if let prevText = UserDefaults.standard.string(forKey: textUserDefaultsKey) {
//            TmpNoteViewController.saveTextIfChanged(note: prevText, viewIndex: 1) { (saved) in
//                if saved == true {
//                    //Nulify old text storage
//                    UserDefaults.standard.removeObject(forKey: textUserDefaultsKey)
//                }
//            }
//        }
//    }
//
//    static private func migrateSketch() {
//        let sketchUserDefaultsKey = "PreviousSessionSketch"
//
//        if let encodedLines = UserDefaults.standard.value(forKey: sketchUserDefaultsKey) as? [Data] {
//            var lines = [SKShapeNode]()
//            for data in encodedLines {
//                if let bp = NSKeyedUnarchiver.unarchiveObject(with: data) as? NSBezierPath {
//                    let path = bp.cgPath
//                    let newLine = SKShapeNode(path: path)
//                    newLine.strokeColor = .textColor
//                    lines.append(newLine)
//                }
//            }
//
//            TmpNoteViewController.saveSketchIfChanged(lines: lines) { (saved) in
//                if saved == true {
//                    //Nulify old sketch storage
//                    UserDefaults.standard.removeObject(forKey: sketchUserDefaultsKey)
//                }
//            }
//        }
//    }
//
//    static public func migrate() {
//        migrateText()
//        migrateSketch()
//    }
//}

class CustomRadioButton: NSButton {

    func toggleState(newState: StateValue) {
        self.state = newState
        let imageName = self.state == .on ? "page_indicator_active" : "page_indicator"
        self.image = NSImage(named: imageName)
    }
}

class NoteTextView: NSTextView {
    
    var storageDataSource: StorageDataSource?

    override func keyDown(with event: NSEvent) {

        // ⌘S - Save content
        if event.modifierFlags.contains(.command) && event.keyCode == kVK_ANSI_S {
            DatasourceController.shared.saveText(newContent: self.string)
//            storageDataSource?.save()
        }

        super.keyDown(with: event)
    }
}
