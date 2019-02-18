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
    var eventMonitor: EventMonitor?
    let preferences = PreferencesWindowController.freshController()
    
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        setupLaunchOnStartup()
        killLauncher()
        
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            let isLocked = UserDefaults.standard.bool(forKey: "locked")
            if let strongSelf = self, strongSelf.popover.isShown, isLocked == false {
                strongSelf.closePopover()
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
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    private func createStatusBarIcon() {
        
        if let button = statusItem.button {
            button.image = NSImage(named: "Compose")
            button.action = #selector(AppDelegate.togglePopover(_:))
        }
        
        let savedText = TmpNoteViewController.loadText()
        let savedSketch = TmpNoteViewController.loadSketch()
        toggleMenuIcon(fill: (savedText.isEmpty == false || savedSketch.count > 0))
    }
    
    public func toggleMenuIcon(fill: Bool) {
        var iconShouldBeFilled = fill
        let isDynamicIconON = UserDefaults.standard.bool(forKey: "DynamicIcon")
        if isDynamicIconON == false {
            iconShouldBeFilled = false
        }

        let colorIndex = UserDefaults.standard.integer(forKey: "iconFillColor")
        let iconColor: NSColor = IconColor(rawValue: colorIndex)?.color() ?? .textColor
        let resultColor = iconShouldBeFilled ? iconColor : .textColor

        if #available(OSX 10.14, *) {
            let image = iconShouldBeFilled ? NSImage(named: "Compose_bg_template") : NSImage(named: "Compose")
            statusItem.button?.image = image
            statusItem.button?.contentTintColor = resultColor
        }
        else {
            let image = iconShouldBeFilled ? NSImage(named: "Compose_bg3") : NSImage(named: "Compose")
            
            image?.isTemplate = false
            if IconColor(rawValue: colorIndex) == .default {
                image?.isTemplate = true
            }
            
            statusItem.button?.image = image
            
            let img = image?.tintedImage(tintColor: resultColor)
            statusItem.button?.image = img
        }
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
    @objc func togglePopover(_ sender: Any?) {
        popover.isShown == true ? closePopover() : showPopover()
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
        }
    }
    
    func closePopover() {
        popover.performClose(self)
        (popover.contentViewController as! TmpNoteViewController).save()
        eventMonitor?.stop()
        UserDefaults.standard.synchronize()
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
}

extension NSImage {
    convenience init(color: NSColor, size: NSSize) {
        self.init(size: size)
        lockFocus()
        color.drawSwatch(in: NSRect(origin: .zero, size: size))
        unlockFocus()
    }
    
    func tintedImage(tintColor: NSColor?) -> NSImage {
        guard let tinted = self.copy() as? NSImage else { return self }
        guard let tint = tintColor else { return self }
        
        tinted.lockFocus()
        tint.set()
        let imageRect = NSRect(origin: NSZeroPoint, size: tinted.size)
        __NSRectFillUsingOperation(imageRect, .sourceAtop)
        tinted.unlockFocus()
        
        return tinted
    }
}
