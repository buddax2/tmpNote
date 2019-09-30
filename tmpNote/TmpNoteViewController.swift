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
    static let kPreviousSessionSelectedListKey = "PreviousSessionSelectedList"
    static let kListsKey = "Lists"
    static let kPreviousSessionModeKey = "PreviousMode"
    
    var drawingScene: DrawingScene?
    var skview: SKView?
    
    @objc lazy var moc: NSManagedObjectContext = {
        return (NSApplication.shared.delegate as? AppDelegate)!.persistentContainer.viewContext
    }()
    
    @IBOutlet var arrayController: NSArrayController!

    var tmpLockMode = false

    var currentListID: Int? {
        didSet {
//            if let title = listButton.titleOfSelectedItem {
//                debugPrint(title)
//                textView.string = load(listName: title) ?? ""
//            }

            if let idx = currentListID {
                arrayController.setSelectionIndex(idx)
            }
            
//            guard let listID = currentListID else { return }
//            listButton.selectItem(at: listID)

//            guard oldValue != listID else {
//                return
//            }
//
//            if let oldValue = oldValue {
//                TmpNoteViewController.saveText(note: textView.string, listID: oldValue)
//            }
            
//            let text = TmpNoteViewController.loadText(listID: listID)
//            textView.string = text
            
            textView.checkTextInDocument(nil)
        }
    }
    
    @IBOutlet weak var listButton: NSPopUpButton!
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
    
    var lists = [Draft]()
    var lines = [SKShapeNode]() {
        didSet {
            contentDidChange()
        }
    }
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
//        save()
        
        switch currentMode {
            case .text:
                createDrawScene()
            case .sketch:
                removeDrawScene()
        }
    }
    
    @IBAction func switchToView(_ sender: NSPopUpButton) {

//        save()
        currentListID = sender.indexOfSelectedItem
        
//        sender.selectedItem!.title
//        textView.string = lists.filter{ $0.ID == currentListID }.first?.note ?? ""
//        textView.string = TmpNoteViewController.loadText(listID: currentListID)
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
        loadSubstitutions()
        
        
        
//        if let listsData = UserDefaults.standard.data(forKey: TmpNoteViewController.kListsKey) {
//            let listsArray = try? JSONDecoder().decode([List].self, from: listsData)
//            if let l = listsArray {
//                lists = l
//            }
//
//            listButton.removeAllItems()
//            lists.forEach { item in
//                listButton.addItem(withTitle: item.title)
//            }
//        }
        
//        let lastListID = UserDefaults.standard.integer(forKey: TmpNoteViewController.kPreviousSessionSelectedListKey)
//        currentListID = lastListID
        
//        listButton.selectItem(at: lastListID)
        
        if let titles = arrayController.selectedObjects as? [Draft], let obj = titles.first?.body {
//            textView.string = String(data: obj as Data, encoding: .utf8) ?? ""
            textView.string = obj
            
//            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "List")
//            fetchRequest.predicate = NSPredicate(format: "title = %@", title)
//
//            do {
//                let results = try moc.fetch(fetchRequest) as? [List]
//                if results?.count != 0 { // Atleast one was returned
//
//                    // In my case, I only updated the first item in results
//                    if let data = textView.string.data(using: .utf8) as NSData? {
//                        results?.first?.body = data
//                    }
//                }
//            } catch {
//                print("Fetch Failed: \(error)")
//            }
        }


        
        textView.checkTextInDocument(nil)

        loadSketch()
    }
    
    func load(listName: String) -> String? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Draft")
        fetchRequest.predicate = NSPredicate(format: "title = %@", listName)
        
        do {
            let results = try moc.fetch(fetchRequest) as? [Draft]
            return results?.first?.body ?? ""
//            if let firstList = results?.first, let body = firstList.body as Data? {
//                return String(data: body, encoding: .utf8)
//            }
        } catch {
            print("Fetch Failed: \(error)")
        }

        return nil
    }
    
    func loadSketch() {
//        lines = TmpNoteViewController.loadSketch()
//
//        contentDidChange()
        
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Sketch")
        
        do {
            let results = try moc.fetch(fetchRequest) as? [Sketch]
            if results?.count != 0 { // Atleast one was returned
                lines = TmpNoteViewController.loadSketch(encodedData: results?.first?.body)
//                if let encodedData = results?.first?.body {
//                    if let decodedArray = NSKeyedUnarchiver.unarchiveObject(with: encodedData) as? [Data] {
//                        lines = TmpNoteViewController.loadSketch()
//                    }
//                }
            }
        } catch {
            print("Fetch Failed: \(error)")
        }

    }
    
    static func loadText() -> String {
        
        let currentListID: Int = UserDefaults.standard.integer(forKey: TmpNoteViewController.kPreviousSessionSelectedListKey)

        return TmpNoteViewController.loadText(listID: currentListID)
    }
    
    private static func loadText(listID: Int) -> String {
        var text = ""
        
        var currentListID = TmpNoteViewController.kPreviousSessionTextKey
        if listID > 0 {
            currentListID += String(listID)
        }

        if let savedText = UserDefaults.standard.string(forKey: currentListID)  {
            text = savedText
        }
        
        return text
    }
    
    static func saveText(note: String, listID: Int = 0) {
        var listIDStr = TmpNoteViewController.kPreviousSessionTextKey
        if listID > 0 {
            listIDStr += String(listID)
        }
        
        UserDefaults.standard.set(note, forKey: listIDStr)
    }
    
    func loadSubstitutions() {
        textView.isAutomaticDashSubstitutionEnabled = UserDefaults.standard.object(forKey: "SmartDashes") != nil ? UserDefaults.standard.bool(forKey: "SmartDashes") : true
        textView.isAutomaticSpellingCorrectionEnabled = UserDefaults.standard.object(forKey: "SmartSpelling") != nil ? UserDefaults.standard.bool(forKey: "SmartSpelling") : true
        textView.isAutomaticTextReplacementEnabled = UserDefaults.standard.object(forKey: "SmartTextReplacing") != nil ? UserDefaults.standard.bool(forKey: "SmartTextReplacing") : true
        textView.isAutomaticDataDetectionEnabled = UserDefaults.standard.object(forKey: "SmartDataDetection") != nil ? UserDefaults.standard.bool(forKey: "SmartDataDetection") : true
        textView.isAutomaticQuoteSubstitutionEnabled = UserDefaults.standard.object(forKey: "SmartQuotes") != nil ? UserDefaults.standard.bool(forKey: "SmartQuotes") : true
        textView.isAutomaticLinkDetectionEnabled = UserDefaults.standard.object(forKey: "SmartLinks") != nil ? UserDefaults.standard.bool(forKey: "SmartLinks") : true
    }

    static func loadSketch(encodedData: Data?) -> [SKShapeNode] {
        guard let encodedData = encodedData else { return [] }
        var lines = [SKShapeNode]()
        
        if let decodedArray = NSKeyedUnarchiver.unarchiveObject(with: encodedData) as? [Data] {
            for data in decodedArray {
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
    
    func save(listName: String) {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Draft")
        fetchRequest.predicate = NSPredicate(format: "title = %@", listName)
        
        do {
            let results = try moc.fetch(fetchRequest) as? [Draft]
            if results?.count != 0 { // Atleast one was returned

//                // In my case, I only updated the first item in results
//                if let data = textView.string.data(using: .utf8) as NSData? {
//                    results?.first?.body = data
//                }
                
                results?.first?.body = textView.string
            }
        } catch {
            print("Fetch Failed: \(error)")
        }

        do {
            try moc.save()
        }
        catch {
            print("Saving Core Data Failed: \(error)")
        }
    }
    
    func save() {
        if let title = listButton.titleOfSelectedItem {
            save(listName: title)
        }
        
//        guard let currentListID = currentListID else { return }
        UserDefaults.standard.set(currentListID, forKey: TmpNoteViewController.kPreviousSessionSelectedListKey)
        UserDefaults.standard.set(currentMode.rawValue, forKey: TmpNoteViewController.kPreviousSessionModeKey)
//        TmpNoteViewController.saveText(note: textView.string, listID: currentListID)
        
//        if let listsData = try? JSONEncoder().encode(lists) {
//            UserDefaults.standard.set(listsData, forKey: TmpNoteViewController.kListsKey)
//        }
        
        saveSubstitutions()
        
        saveSketch()
    }
    
    func saveLists() {
        
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
        let encodedData = NSKeyedArchiver.archivedData(withRootObject: encodedLines)
        
//        UserDefaults.standard.set(encodedLines, forKey: DrawingScene.saveKey)
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Sketch")
        
        do {
            let results = try moc.fetch(fetchRequest) as? [Sketch]
            if results?.count != 0 { // Atleast one was returned
                results?.first?.body = encodedData
            }
            else {
                let sketchEntity = NSEntityDescription.entity(forEntityName: "Sketch", in: moc)
                
                let newSketch = NSManagedObject(entity: sketchEntity! , insertInto: moc) as! Sketch
                newSketch.body = encodedData
            }
        } catch {
            print("Fetch Failed: \(error)")
        }
        
        do {
            try moc.save()
        }
        catch {
            print("Saving Core Data Failed: \(error)")
        }

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
//        lists[currentListID ?? 0].note = textView.string
//        save()
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
