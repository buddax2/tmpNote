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

    let markdownHighlighter = MarkdownHighlighter()

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
            textView.textStorage?.delegate = markdownHighlighter
            textView.onPreviewTodoToggle = { [weak self] location in
                self?.togglePreviewTodo(at: location)
            }
            DispatchQueue.main.async { [weak self] in
                self?.setupTextView()
            }
        }
    }
    @IBOutlet weak var lockButton: NSButton! {
        didSet {
            let isLocked = DatasourceController.shared.isLocked
            lockButton.image = isLocked ? NSImage(named: "NSLockLockedTemplate") : NSImage(named: "NSLockUnlockedTemplate")
            lockButton.toolTip = isLocked ? "Do Not Hide on Deactivate ⌘L" : "Hide on Deactivate ⌘L"
        }
    }
    
    func syncUI(newMode: Mode? = nil) {
        let mode: Mode = newMode ?? DatasourceController.shared.currentMode
        
        contentTouchBarButton.selectedSegment = mode.rawValue
        contentModeButton.selectedSegment = mode.rawValue
        
        switch mode {
        case .text:
            removeDrawScene()
            showPlainText()
        case .markdown:
            removeDrawScene()
            showMarkdown()
        case .sketch:
            createDrawScene()
        }
        
        clearButton.isEnabled = mode == .text || mode == .sketch
    }

    var subscribers = Set<AnyCancellable>()

    var currentFontSize: CGFloat {
        let fontSize = UserDefaults.standard.value(forKey: TmpNoteViewController.kFontSizeKey) as? Int ?? TmpNoteViewController.defaultFontSize
        return CGFloat(fontSize)
    }

    /// Read-only preview: fully rendered markdown with the markers removed.
    func showMarkdown() {
        // The rendered text must not be restyled as raw markdown
        markdownHighlighter.isEnabled = false
        textView.isEditable = false

        textView.textStorage?.setAttributedString(renderedMarkdown(DatasourceController.shared.content))
    }

    /// Checks/unchecks a to-do from the read-only preview by flipping its `[ ]` in the saved note.
    func togglePreviewTodo(at location: Int) {
        let content = DatasourceController.shared.content as NSString
        guard location < content.length else { return }

        let stateRange = NSRange(location: location, length: 1)
        let state = content.substring(with: stateRange)
        guard [" ", "x", "X"].contains(state) else { return }

        DatasourceController.shared.content = content.replacingCharacters(in: stateRange, with: state == " " ? "x" : " ")
        DatasourceController.shared.save()
        showMarkdown()
    }

    private static let uncheckedPlaceholder = "\u{2610}\u{2003}" // ☐ + em space
    private static let checkedPlaceholder = "\u{2611}\u{2003}"   // ☑ + em space

    /// Renders the note with SwiftyMarkdown. To-do markers become placeholders that
    /// NoteTextView draws as checkboxes, and completed items are crossed out.
    func renderedMarkdown(_ text: String) -> NSAttributedString {
        let taskRegex = MarkdownHighlighter.taskRegex
        let mutableText = NSMutableString(string: text)
        let taskMatches = taskRegex.matches(in: text, range: NSRange(location: 0, length: mutableText.length))
        // Where each task's `[ ]` state character lives in the note, in document order
        let stateLocations = taskMatches.map { $0.range(at: 2).location }

        // Reverse order keeps the earlier match ranges valid
        for m in taskMatches.reversed() {
            let isChecked = mutableText.substring(with: m.range(at: 2)) != " "
            let item = m.range(at: 3).location != NSNotFound ? mutableText.substring(with: m.range(at: 3)) : ""
            let markerStart = m.range(at: 1).location
            let replaceRange = NSRange(location: markerStart, length: NSMaxRange(m.range) - markerStart)
            mutableText.replaceCharacters(in: replaceRange, with: (isChecked ? Self.checkedPlaceholder : Self.uncheckedPlaceholder) + item)
        }

        let md = markdown(text: mutableText as String, baseFontSize: currentFontSize, color: .textColor)
        let rendered = NSMutableAttributedString(attributedString: md.attributedString())
        let renderedText = rendered.string as NSString
        var markers = [NSRange]()

        renderedText.enumerateSubstrings(in: NSRange(location: 0, length: renderedText.length), options: .byLines) { line, lineRange, _, _ in
            guard let line = line else { return }
            let trimmed = line.drop { $0 == " " || $0 == "\t" }
            let isChecked = trimmed.hasPrefix(Self.checkedPlaceholder)
            guard isChecked || trimmed.hasPrefix(Self.uncheckedPlaceholder) else { return }

            let markerStart = lineRange.location + (line as NSString).length - (String(trimmed) as NSString).length
            let marker = NSRange(location: markerStart, length: (Self.checkedPlaceholder as NSString).length)
            rendered.addAttributes([.todoCheckbox: isChecked, .foregroundColor: NSColor.clear], range: marker)
            markers.append(marker)

            let item = NSRange(location: NSMaxRange(marker), length: NSMaxRange(lineRange) - NSMaxRange(marker))
            if isChecked && item.length > 0 {
                rendered.addAttributes([
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .foregroundColor: NSColor.secondaryLabelColor,
                ], range: item)
            }
        }

        // Link each checkbox back to its task in the note so it can be toggled from the preview.
        // If the counts differ the mapping would be ambiguous, so leave them non-clickable.
        if markers.count == stateLocations.count {
            for (marker, location) in zip(markers, stateLocations) {
                rendered.addAttribute(.todoSourceLocation, value: location, range: marker)
            }
        }

        return rendered
    }

    /// Fully rendered markdown (markers removed), used by the preview and when sharing it.
    func markdown(text: String, baseFontSize: CGFloat, color: NSColor) -> SwiftyMarkdown {
        let md = SwiftyMarkdown(string: text)
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
    
    /// Edit mode: the raw text stays editable and MarkdownHighlighter styles it in place as you type.
    func showPlainText() {
        markdownHighlighter.isEnabled = false

        textView.string = DatasourceController.shared.content
        textView.isEditable = true

        // Applies the font size and the markdown highlighting
        setupTextView()
    }

    func highlightMarkdown() {
        guard let storage = textView.textStorage else { return }

        markdownHighlighter.baseFontSize = currentFontSize
        markdownHighlighter.isEnabled = true
        markdownHighlighter.highlight(storage)
        textView.typingAttributes = markdownHighlighter.baseAttributes
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.

        shareButton.sendAction(on: .leftMouseDown)

        // Subscribe once here: the popover reuses this controller, so subscribing
        // in viewWillAppear would stack a duplicate subscription on every show.
        DatasourceController.shared.doLoadNoteSubject
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in

            }, receiveValue: { [weak self] newContent in
                self?.syncUI()
            })
            .store(in: &self.subscribers)

//        DatasourceController.shared.$currentViewIndex
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] newIndex in
//                self?.setupViewButtons()
//            }
//            .store(in: &self.subscribers)

        DatasourceController.shared.$currentMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newMode in
                self?.contentModeButton.setSelected(true, forSegment: newMode.rawValue)
                self?.syncUI(newMode: newMode)
            }
            .store(in: &self.subscribers)
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        self.loadSubstitutions()

        DatasourceController.shared.load()

        refreshLockState()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
    }
    
    override func viewWillDisappear() {
        saveSubstitutions()

        drawingScene?.removeFromParent()
        skview?.removeFromSuperview()
        
        textareaScrollView.isHidden = false
        drawingView.isHidden = true

        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.isPresented = false
        
        DatasourceController.shared.save()
        
        super.viewWillDisappear()
    }

    @IBAction func contentModeDidChange(_ sender: NSSegmentedControl) {
        guard let contentMode = Mode(rawValue: sender.selectedSegment) else { return }
        if DatasourceController.shared.currentMode != contentMode {
            DatasourceController.shared.currentMode = contentMode
            DatasourceController.shared.save()
            DatasourceController.shared.load()
        }
    }
    
    @IBAction func pageTouchBarDidChange(_ sender: NSSegmentedControl) {
        changeView(viewIndex: sender.selectedSegment + 1)
    }
    
    func createDrawScene() {
        drawingScene?.removeAllChildren()
        skview?.removeFromSuperview()
        
        skview = SKView(frame: drawingView.bounds)
        drawingView.addSubview(skview!)
        drawingScene = SKScene(fileNamed: "DrawingScene") as? DrawingScene
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
//        let enabled = DatasourceController.shared.currentMode != .sketch
        let enabled = true
        let selectedTag = DatasourceController.shared.currentViewIndex
        
        pageTouchBarButton.selectedSegment = selectedTag - 1
        
        if let buttons = viewButtons.arrangedSubviews as? [CustomRadioButton] {
            buttons.forEach {
                $0.isEnabled = enabled
                $0.toggleState(newState: $0.tag == selectedTag ? .on : .off)
            }
        }
    }
    
    func changeView(viewIndex: Int) {
//        DatasourceController.shared.saveText()
//        DatasourceController.shared.save()
//        DatasourceController.shared.currentViewIndex = viewIndex
//        DatasourceController.shared.load()
//        DatasourceController.shared.loadNote()
//        DatasourceController.shared.load(index: viewIndex)
        DatasourceController.shared.save()

        DatasourceController.shared.load(index: viewIndex)
        
        syncUI()
    }
    
    @IBAction func changeView(_ sender: NSButton) {
        changeView(viewIndex: sender.tag)
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
        
        // textView.font flattens every font in the note, so re-apply the styling
        switch DatasourceController.shared.currentMode {
        case .text:
            highlightMarkdown()
        case .markdown:
            showMarkdown()
        case .sketch:
            break
        }
    }
    
    static let substitutionKeys = ["SmartDashes", "SmartSpelling", "SmartTextReplacing", "SmartDataDetection", "SmartQuotes", "SmartLinks", "GrammarChecking", "SpellChecking"]
    static let substitutionsOffByDefaultKey = "SubstitutionsOffByDefault"

    func loadSubstitutions() {
        let defaults = UserDefaults.standard

        // Spelling, grammar and smart substitutions are now off by default. The old
        // defaults (all on) were saved on every close, so clear them once to apply it.
        if !defaults.bool(forKey: TmpNoteViewController.substitutionsOffByDefaultKey) {
            TmpNoteViewController.substitutionKeys.forEach { defaults.removeObject(forKey: $0) }
            defaults.set(true, forKey: TmpNoteViewController.substitutionsOffByDefaultKey)
        }

        func isEnabled(_ key: String) -> Bool {
            return defaults.object(forKey: key) as? Bool ?? false
        }

        textView.isAutomaticDashSubstitutionEnabled = isEnabled("SmartDashes")
        textView.isAutomaticSpellingCorrectionEnabled = isEnabled("SmartSpelling")
        textView.isAutomaticTextReplacementEnabled = isEnabled("SmartTextReplacing")
        textView.isAutomaticDataDetectionEnabled = isEnabled("SmartDataDetection")
        textView.isAutomaticQuoteSubstitutionEnabled = isEnabled("SmartQuotes")
        textView.isAutomaticLinkDetectionEnabled = isEnabled("SmartLinks")
        textView.isGrammarCheckingEnabled = isEnabled("GrammarChecking")
        textView.isContinuousSpellCheckingEnabled = isEnabled("SpellChecking")
    }

    @IBAction func lockAction(_ sender: Any) {
        DatasourceController.shared.isLocked.toggle()
        
        refreshLockState()
    }
    
    @IBAction func toggleWindowState(_ sender: Any) {
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.toggleWindowState()
    }
    
    func refreshLockState() {
        let isLocked = DatasourceController.shared.isLocked
        lockButton.image = isLocked ? NSImage(named: "NSLockLockedTemplate") : NSImage(named: "NSLockUnlockedTemplate")
        lockButton.toolTip = isLocked ? "Do Not Hide on Deactivate" : "Hide on Deactivate"
        lockTouchBarButton.image = isLocked ? NSImage(named: "NSLockLockedTemplate") : NSImage(named: "NSLockUnlockedTemplate")
        
        
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.changeLockMode()
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
        switch DatasourceController.shared.currentMode {
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
                
                switch DatasourceController.shared.currentMode {
                    case .text, .markdown:
                        if let textLength = strongSelf.textView.textStorage?.length {
                            strongSelf.textView.insertText("", replacementRange: NSRange(location: 0, length: textLength))
                        }

                    case .sketch:
                        self?.drawingScene?.clear()
                }

                // Update the content before saving, otherwise the old text gets persisted
                self?.contentDidChange()
                DatasourceController.shared.save()
            }
        })
    }
    
    @IBAction func shareAction(_ sender: NSButton) {
        var sharedItems = [Any]()
        
        switch DatasourceController.shared.currentMode {
            case .text:
                sharedItems = [textView.string];
            case .sketch:
                if let image = imageFromScene() {
                    sharedItems = [image]
                }
            case .markdown:
                let md = markdown(text: DatasourceController.shared.content, baseFontSize: currentFontSize, color: .textColor)
                sharedItems = [md.attributedString()];
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

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard commandSelector == #selector(NSResponder.insertNewline(_:)),
              DatasourceController.shared.currentMode == .text,
              let noteTextView = textView as? NoteTextView else { return false }

        return noteTextView.continueList()
    }
    
    func contentDidChange() {
        if DatasourceController.shared.currentMode == .text {
            DatasourceController.shared.content = textView.string
        }
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

class CustomRadioButton: NSButton {

    func toggleState(newState: StateValue) {
        self.state = newState
        let imageName = self.state == .on ? "page_indicator_active" : "page_indicator"
        self.image = NSImage(named: imageName)
    }
}
