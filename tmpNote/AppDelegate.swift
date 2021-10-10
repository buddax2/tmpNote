//
//  AppDelegate.swift
//  tmpNote
//
//  Created by BUDDAx2 on 9/23/17.
//  Copyright © 2017 BUDDAx2. All rights reserved.
//

import Cocoa
import ServiceManagement

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    fileprivate var launcherIdentifier: String {
       return  Bundle.main.bundleIdentifier!+".LauncherApplication"
    }
    let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
    let popover = NSPopover()
    var panel: NSPanel?
    var isPresented = false
    
    var eventMonitor: EventMonitor?
    var isInPopover = true
    let preferences = PreferencesWindowController.freshController()
    var containerUrl: URL? {
        return FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents")
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {

        setDefaultSettings()
        
        TmpNoteViewController.migrate()
        
        setupLaunchOnStartup()
        killLauncher()
        
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            let isLocked = UserDefaults.standard.bool(forKey: "locked")
            if let strongSelf = self, strongSelf.popover.isShown, isLocked == false {
                strongSelf.close()
            }
        }
        
        createStatusBarIcon()
        popover.animates = false
        popover.contentViewController = TmpNoteViewController.freshController()

        // Force light appearance for OSX < 10.14
        let majorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        let minorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.minorVersion
        
        if majorVersion == 10 && minorVersion < 14 {
            popover.appearance = NSAppearance(named: .vibrantLight)
        }
        
        // check for container existence
        if let url = self.containerUrl, !FileManager.default.fileExists(atPath: url.path, isDirectory: nil) {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            }
            catch {
                print(error.localizedDescription)
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    private func createStatusBarIcon() {
        
        if let button = statusItem.button {
            button.image = NSImage(named: "Compose")
            button.action = #selector(AppDelegate.togglePopover(_:))
        }
        
        DispatchQueue.main.async { [weak self] in
            TmpNoteViewController.loadText(viewIndex: 1) { (savedText) in
                TmpNoteViewController.loadSketch { (savedSketch) in
                    self?.toggleMenuIcon(fill: (savedText.isEmpty == false || savedSketch.count > 0))
                }
            }
        }
    }
    
    func setDefaultSettings() {
        let syncSettingsExists = UserDefaults.standard.value(forKey: "SynchronizeContent")
        if syncSettingsExists == nil {
            UserDefaults.standard.set(true, forKey: "SynchronizeContent")
        }
    }
    
    public func toggleMenuIcon(fill: Bool) {
        var iconShouldBeFilled = fill
        let isDynamicIconON = UserDefaults.standard.bool(forKey: "DynamicIcon")
        if isDynamicIconON == false {
            iconShouldBeFilled = false
        }

        let colorIndex = UserDefaults.standard.integer(forKey: "iconFillColor")
        let iconColor: NSColor = IconColor(rawValue: colorIndex)?.color() ?? IconColor.defaultColor()
        let resultColor = iconShouldBeFilled ? iconColor : IconColor.defaultColor()
        
        let image = iconShouldBeFilled ? NSImage(named: "Compose_bg_template") : NSImage(named: "Compose")
        let img = image?.image(with: resultColor)
        statusItem.button?.image = img
    }
    
    fileprivate func killLauncher() {
        var startAtLogin = false
        for app in NSWorkspace.shared.runningApplications {
            if app.bundleIdentifier == launcherIdentifier {
                startAtLogin = true
            }
        }
        
        if startAtLogin == true {
            DistributedNotificationCenter.default().post(name: Notification.Name(rawValue: "killme"), object: Bundle.main.bundleIdentifier)
        }
    }
    
    //MARK: Menu actions
    
    @IBAction func switchToPlainText(_ sender: NSMenuItem) {
        (self.popover.contentViewController as! TmpNoteViewController).currentMode = .text
    }
    
    @IBAction func switchToMarkdown(_ sender: NSMenuItem) {
        (self.popover.contentViewController as! TmpNoteViewController).currentMode = .markdown
    }
    
    @IBAction func switchToDrawing(_ sender: NSMenuItem) {
        (self.popover.contentViewController as! TmpNoteViewController).currentMode = .sketch
    }
    
    @objc func togglePopover(_ sender: Any?) {
        if isInPopover {
            isPresented == true ? close() : show()
        }
        else {
            panel?.isKeyWindow == true ? close() : show()
        }
    }
    
    @objc func openPreferences() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        preferences.window?.makeKeyAndOrderFront(self)
    }
    
    @objc func quitAction() {
        NSApp.terminate(self)
    }
    
    //MARK: Popover Show/Hide
    func showPopover() {
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            NSApplication.shared.activate(ignoringOtherApps: true)
            eventMonitor?.start()
            DispatchQueue.main.async { [weak self] in
                (self?.popover.contentViewController as! TmpNoteViewController).load()
            }
        }
    }
    
    func closePopover() {
        popover.performClose(self)
        DispatchQueue.main.async { [weak self] in
            (self?.popover.contentViewController as! TmpNoteViewController).save()
        }
        eventMonitor?.stop()
        UserDefaults.standard.synchronize()
    }
    
    func closePanel() {
        DispatchQueue.main.async { [weak self] in
            if let controller = self?.panel?.contentViewController as? TmpNoteViewController {
                controller.save()
            }
        }
        panel?.close()
    }
    
    func setupLaunchOnStartup() {
        
        var shouldLaunch = false
        if let _ = UserDefaults.standard.object(forKey: "LaunchOnStartup") {
            shouldLaunch = UserDefaults.standard.bool(forKey: "LaunchOnStartup")
        }
        else {
            UserDefaults.standard.set(false, forKey: "LaunchOnStartup")
        }
        
        SMLoginItemSetEnabled(launcherIdentifier as CFString, shouldLaunch)
    }
    
    func toggleWindowState() {
        isInPopover.toggle()
        show()
    }
    
    func show() {
        isPresented = true

        if isInPopover {
            closePanel()
            showPopover()
            return
        }
        
        closePopover()
        
        if panel != nil {
            DispatchQueue.main.async {
                self.panel?.orderFrontRegardless()
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
            return
        }
        
        let noteController = TmpNoteViewController.freshController()

        let isLocked = UserDefaults.standard.bool(forKey: "locked") == true
        let panelStyleMask: NSWindow.StyleMask = isLocked ? [.titled, .closable, .nonactivatingPanel] : [.titled, .closable]
        panel = NSPanel(contentRect: popover.positioningRect, styleMask: panelStyleMask, backing: .buffered, defer: true)
        panel?.level = .mainMenu
        panel?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel?.contentViewController = noteController
        if let bounds = statusItem.button?.window?.frame {
            panel?.setFrameTopLeftPoint(CGPoint(x: bounds.midX - noteController.view.bounds.width/2, y: bounds.minY))
        }
        panel?.isFloatingPanel = isLocked
        panel?.orderFrontRegardless()
        noteController.load()
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    func close() {
        isPresented = false
        
        if isInPopover {
            closePopover()
            return
        }
        
        closePanel()
    }
    
    func changeLockMode(locked: Bool) {
        guard isInPopover == false else { return }
        
        let panelStyleMask: NSWindow.StyleMask = locked ? [.titled, .closable, .nonactivatingPanel] : [.titled, .closable]
        panel?.styleMask = panelStyleMask
        panel?.isFloatingPanel = locked
    }
}

extension NSImage {
    convenience init(color: NSColor, size: NSSize) {
        self.init(size: size)
        lockFocus()
        color.drawSwatch(in: NSRect(origin: .zero, size: size))
        unlockFocus()
    }
    
    func image(with tintColor: NSColor) -> NSImage {
        guard self.isTemplate else { return self }
        
        let image = self.copy() as! NSImage
            image.lockFocus()
            tintColor.set()
        
        let imageRect = NSRect(origin: .zero, size: image.size)
            imageRect.fill(using: .sourceIn)
            image.unlockFocus()
            image.isTemplate = false
        
        return image
    }
}

extension Notification.Name {
    static let AppleInterfaceThemeChangedNotification = Notification.Name("AppleInterfaceThemeChangedNotification")
}
