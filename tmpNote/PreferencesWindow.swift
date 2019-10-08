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
        
        let storyBoard = NSStoryboard(name: "Main", bundle: nil)
        let identifier = "PreferencesWindowController"
        guard let vc = storyBoard.instantiateController(withIdentifier: identifier) as? PreferencesWindowController else {
            
            fatalError("Can't instantiate PreferencesWindowController. Check Main.storyboard")
        }
        
        return vc
    }
}

class PreferencesTabViewController: NSTabViewController {

    private lazy var tabViewSizes: [NSTabViewItem: NSSize] = [:]

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)

        if let tabViewItem = tabViewItem {
            view.window?.title = tabViewItem.label
            resizeWindowToFit(tabViewItem: tabViewItem)
        }
    }

    override func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, willSelect: tabViewItem)

        // Cache the size of the tab view.
        if let tabViewItem = tabViewItem, let size = tabViewItem.view?.frame.size {
            tabViewSizes[tabViewItem] = size
        }
    }

    /// Resizes the window so that it fits the content of the tab.
    private func resizeWindowToFit(tabViewItem: NSTabViewItem) {
        guard let size = tabViewSizes[tabViewItem], let window = view.window else {
            return
        }

        let contentRect = NSRect(x: 0, y: 0, width: size.width, height: size.height)
        let contentFrame = window.frameRect(forContentRect: contentRect)
        let toolbarHeight = window.frame.size.height - contentFrame.size.height
        let newOrigin = NSPoint(x: window.frame.origin.x, y: window.frame.origin.y + toolbarHeight)
        let newFrame = NSRect(origin: newOrigin, size: contentFrame.size)
        window.setFrame(newFrame, display: false, animate: true)
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
    
    static func freshController() -> GeneralViewController {
        
        let storyBoard = NSStoryboard(name: "Main", bundle: nil)
        let identifier = "GeneralViewController"
        guard let vc = storyBoard.instantiateController(withIdentifier: identifier) as? GeneralViewController else {
            
            fatalError("Can't instantiate GeneralViewController. Check Main.storyboard")
        }
        
        return vc
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
        let storyBoard = NSStoryboard(name: "Main", bundle: nil)
        let identifier = "PopoverAnimationVC"
        guard let vc = storyBoard.instantiateController(withIdentifier: identifier) as? PopoverAnimationVC else { return }
        popover.contentViewController = vc
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: NSRectEdge.maxX)
    }
}

@objc class Note: NSObject {
    @objc let name: String
    @objc let path: String
    @objc let url: URL
    
    init(name: String, path: String, url: URL) {
        self.name = name
        self.path = path
        self.url = url
    }
}

class ListsPreferencesViewController: NSViewController, NSTableViewDelegate {
    
    @IBOutlet var arrayController: NSArrayController!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var pathControl: NSPathControl!
    var bookmarks = [URL: Data]()
    
    @objc dynamic var fileNames = [Note]()
    
    static func freshController() -> ListsPreferencesViewController {
        
        let storyBoard = NSStoryboard(name: "Main", bundle: nil)
        let identifier = "ListsPreferencesViewController"
        guard let vc = storyBoard.instantiateController(withIdentifier: identifier) as? ListsPreferencesViewController else {
            
            fatalError("Can't instantiate ListsPreferencesViewController. Check Main.storyboard")
        }
        
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let notes = TmpNoteViewController.loadNotesList()
        fileNames.append(contentsOf: notes)
        bookmarks = TmpNoteViewController.loadBookmarks()
    }

    override func viewDidDisappear() {
        save()
        super.viewDidDisappear()
    }
    
    @IBAction func listAction(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0:
            addList()
        default:
            removeList()
        }
    }
    
    @IBAction func openAction(_ sender: Any) {
        let savePanel = NSOpenPanel()

        setupFilePanel(savePanel)

        savePanel.allowedFileTypes = ["txt"]

        savePanel.canCreateDirectories = true

        savePanel.begin { [weak self] (result) in
            if result.rawValue == NSApplication.ModalResponse.OK.rawValue {
                if let fileURL = savePanel.url {
                    if let fileNameWithExtension = savePanel.url?.lastPathComponent, let fileExtension = savePanel.url?.pathExtension {
                        let fileName = fileNameWithExtension.replacingOccurrences(of: "." + fileExtension, with: "")
                        let note = Note(name: fileName, path: fileURL.path, url: fileURL)
                        self?.fileNames.append(note)
                        
                        self?.storeBookmark(url: fileURL)
                        self?.saveBookmarks()

                    }
                }
            }
        }
    }
    
    func saveBookmarks()
    {
        let url = TmpNoteViewController.bookmarkURL()
        do
        {
            if #available(OSX 10.13, *) {
                let data = try NSKeyedArchiver.archivedData(withRootObject: bookmarks, requiringSecureCoding: false)
                try data.write(to: url)
            } else {
                // Fallback on earlier versions
            }
        }
        catch
        {
            print("Couldn't save bookmarks")
        }
    }

    func storeBookmark(url: URL)
    {
        do
        {
            let data = try url.bookmarkData(options: NSURL.BookmarkCreationOptions.withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            bookmarks[url] = data
        }
        catch
        {
            Swift.print ("Error storing bookmarks")
        }

    }

    func allowFolder(completion: @escaping (URL?) -> Void)
    {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseFiles = true
        openPanel.begin
            { [weak self] (result) -> Void in
                if result == .OK
                {
                    let url = openPanel.url
                    self?.storeBookmark(url: url!)
                    self?.saveBookmarks()
                    completion(url)
                }
        }
    }

    
    func exportHistory() {
        
        let savePanel = NSSavePanel()

        setupFilePanel(savePanel)

        savePanel.allowedFileTypes = ["txt"]

        savePanel.canCreateDirectories = true

        savePanel.begin { [weak self] (result) in
            if result.rawValue == NSApplication.ModalResponse.OK.rawValue {
                if let fileURL = savePanel.url {
                    if let fileNameWithExtension = savePanel.url?.lastPathComponent, let fileExtension = savePanel.url?.pathExtension {
                        let fileName = fileNameWithExtension.replacingOccurrences(of: "." + fileExtension, with: "")
                        let note = Note(name: fileName, path: fileURL.path, url: fileURL)
                        self?.fileNames.append(note)
                        
                        if FileManager.default.fileExists(atPath: fileURL.path) == false {
                            //Just create empty file
                            do {
                                try "".write(to: fileURL, atomically: true, encoding: .utf8)
                                self?.storeBookmark(url: fileURL)
                            } catch {
                                debugPrint(error.localizedDescription)
                            }
                        }
                        else {
                            self?.storeBookmark(url: fileURL)
                        }
                        self?.saveBookmarks()
                    }
                }
            }
        }
    }

    func getFilePathFromPanel(_ panel : NSSavePanel) -> String? {
        
        let url : URL! = panel.url
        
        if url == nil {
            
            return nil
        }
        
        let path : String! = url.path
        
        if path == nil {
            
            return nil
        }

        return path
    }
    
    func setupFilePanel (_ filePanel : NSSavePanel) {
        
        filePanel.showsHiddenFiles = true
        
        filePanel.isExtensionHidden = false
        
        filePanel.treatsFilePackagesAsDirectories = true
    }

    func addList() {
        exportHistory()
//        let savePanel = NSSavePanel()
//        savePanel.canCreateDirectories = true
//        savePanel.showsTagField = false
//        savePanel.nameFieldStringValue = "result.csv"
//        savePanel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.modalPanelWindow)))
//        savePanel.begin { (result) in
//            if result.rawValue == NSApplication.ModalResponse.OK.rawValue {
//
//
//            }
//        }
        
    }
    
    func removeList() {
        fileNames.remove(at: tableView.selectedRow)
    }
    
    func save() {
        let paths = fileNames.map { $0.path }
        UserDefaults.standard.set(paths, forKey: TmpNoteViewController.kFilePathsKey)
        UserDefaults.standard.synchronize()
        (NSApplication.shared.delegate as? AppDelegate)?.loadText()
        ((NSApplication.shared.delegate as? AppDelegate)?.popover.contentViewController as? TmpNoteViewController)?.loadPreviousText()
    }
}

class PopoverAnimationVC: NSViewController {

    @IBOutlet weak var imageView: NSImageView! {
        didSet {
            imageView.canDrawSubviewsIntoLayer = true
            imageView.imageScaling = .scaleNone
            imageView.animates = true
            imageView.image = NSImage(named: "example")
        }
    }
}
