//
//  AppDelegate.swift
//  tmpNote
//
//  Created by BUDDAx2 on 9/23/17.
//  Copyright © 2017 BUDDAx2. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {


    let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
    let popover = NSPopover()
    var eventMonitor: EventMonitor?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let strongSelf = self, strongSelf.popover.isShown {
                strongSelf.closePopover()
            }
        }
        
        if let button = statusItem.button {
            button.image = #imageLiteral(resourceName: " Compose")
            button.action = #selector(AppDelegate.togglePopover(_:))
        }

        createStatusBarMenu()
        popover.contentViewController = TmpNoteViewController.freshController()
        popover.animates = false
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func createStatusBarMenu() {


        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(NSMenuItem(title: "Preferences", action: #selector(openPreferences), keyEquivalent: "P"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit tmpNote", action: #selector(quitAction), keyEquivalent: ""))
        
        statusItem.menu = menu

    }
    
    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems() // TODO: re-work this piece of shit

        if (NSEvent.pressedMouseButtons == 1) {
            togglePopover(menu)
            return
        }
        else {
            menu.addItem(NSMenuItem(title: "Preferences", action: #selector(openPreferences), keyEquivalent: "P"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit tmpNote", action: #selector(quitAction), keyEquivalent: ""))
        }
    }

    @objc func togglePopover(_ sender: Any?) {
        debugPrint("test")
        popover.isShown == true ? closePopover() : showPopover()
    }
    
    @objc func openPreferences() {
        
    }
    
    @objc func quitAction() {
        NSApp.terminate(self)
    }
    
    func showPopover() {
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            eventMonitor?.start()
        }
    }
    
    func closePopover() {
        popover.performClose(self)
        eventMonitor?.stop()
    }
}
