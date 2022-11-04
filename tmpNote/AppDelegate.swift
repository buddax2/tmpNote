//
//  AppDelegate.swift
//  tmpNote
//
//  Created by BUDDAx2 on 9/23/17.
//  Copyright © 2017 BUDDAx2. All rights reserved.
//

import Cocoa
import ServiceManagement
import Combine

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    fileprivate var launcherIdentifier: String {
       return  Bundle.main.bundleIdentifier!+".LauncherApplication"
    }
    let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
    var popover: NSPopover?
    var panel: NSPanel?
    var isPresented = false
    
    var eventMonitor: EventMonitor?
    var isInPopover = true
    let preferences = PreferencesWindowController.freshController()
    var contentSubscriber: AnyCancellable?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setDefaultSettings()
        
        setupLaunchOnStartup()
        killLauncher()
        
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            let isLocked = DatasourceController.shared.isLocked
            if let strongSelf = self, let popover = strongSelf.popover, popover.isShown, isLocked == false {
                strongSelf.close()
            }
        }
        
        createDefaultNotes()
        
//        DatasourceController.shared.context = persistentContainer.viewContext
        
        DatasourceController.shared.load()
        
        createStatusBarIcon()
        
//        // check for container existence
//        if let url = Datasource.containerUrl, !FileManager.default.fileExists(atPath: url.path, isDirectory: nil) {
//            do {
//                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
//            }
//            catch {
//                print(error.localizedDescription)
//            }
//        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        DatasourceController.shared.save()
    }

    private func createStatusBarIcon() {
        
        if let button = statusItem.button {
            button.image = NSImage(named: "Compose")
            button.action = #selector(AppDelegate.togglePopover(_:))
        }
        
        contentSubscriber = DatasourceController.shared.$content
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in
            
            }, receiveValue: { [weak self] newContent in
                self?.toggleMenuIcon(fill: newContent.isEmpty == false)
            })
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
        img?.isTemplate = true
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
        DatasourceController.shared.currentMode = .text
    }
    
    @IBAction func switchToMarkdown(_ sender: NSMenuItem) {
        DatasourceController.shared.currentMode = .markdown
    }
    
    @IBAction func switchToDrawing(_ sender: NSMenuItem) {
        DatasourceController.shared.currentMode = .sketch
    }
    
    @objc func togglePopover(_ sender: Any?) {
        if isPresented {
            close()
        }
        else {
            show()
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
            if popover != nil {
                DispatchQueue.main.async {
                    self.popover?.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    self.eventMonitor?.start()
                }
                return
            }
            
            popover = NSPopover()

            popover?.animates = false
            popover?.contentViewController = TmpNoteViewController.freshController()

            // Force light appearance for OSX < 10.14
            let majorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
            let minorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.minorVersion
            
            if majorVersion == 10 && minorVersion < 14 {
                popover?.appearance = NSAppearance(named: .vibrantLight)
            }
            
            DispatchQueue.main.async {
                self.popover?.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                NSApplication.shared.activate(ignoringOtherApps: true)
                self.eventMonitor?.start()
            }
        }
    }
    
    func closePopover() {
        popover?.performClose(self)
        eventMonitor?.stop()
        UserDefaults.standard.synchronize()
    }
    
    func closePanel() {
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

        let isLocked = DatasourceController.shared.isLocked == true
        let panelStyleMask: NSWindow.StyleMask = isLocked ? [.titled, .closable, .nonactivatingPanel] : [.titled, .closable]
        panel = NSPanel(contentRect: popover?.positioningRect ?? NSRect.zero, styleMask: panelStyleMask, backing: .buffered, defer: true)
        panel?.title = "tmpNote"
        panel?.level = .mainMenu
        panel?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel?.contentViewController = noteController
        if let bounds = statusItem.button?.window?.frame {
            panel?.setFrameTopLeftPoint(CGPoint(x: bounds.midX - noteController.view.bounds.width/2, y: bounds.minY))
        }
        panel?.isFloatingPanel = isLocked
        panel?.orderFrontRegardless()
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
    
    func changeLockMode() {
        guard isInPopover == false else { return }
        
        let panelStyleMask: NSWindow.StyleMask = DatasourceController.shared.isLocked ? [.titled, .closable, .nonactivatingPanel] : [.titled, .closable]
        panel?.styleMask = panelStyleMask
        panel?.isFloatingPanel = DatasourceController.shared.isLocked
    }
    
    // MARK: - Core Data stack

    func createDefaultView(index: Int) {
        let newView = NoteView(context: persistentContainer.viewContext)
        newView.id = Int32(index)
        newView.lastModified = Date()

        do {
            try persistentContainer.viewContext.save()
            debugPrint("created view \(index)")
        } catch {
            debugPrint(error)
        }
    }
    
    func createDefaultNotes() {
        
        for idx in 1...5 {
            let request = NoteView.fetchRequest()
            request.predicate = NSPredicate(format: "id = %d", idx)
            
            do {
                let viewEntities = try persistentContainer.viewContext.fetch(request)

                if viewEntities.isEmpty {
                    createDefaultView(index: idx)
                }
                else {
                    debugPrint("view \(idx) exists")
                }
            } catch {
                debugPrint(error)
            }
        }
        
    }
    
    
    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        let container = NSPersistentCloudKitContainer(name: "tmpNote")

        if !UserDefaults.standard.bool(forKey: "SynchronizeContent") {
            container.persistentStoreDescriptions.forEach { $0.cloudKitContainerOptions = nil }
        }

        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error)")
            }
        })
        return container
    }()

    // MARK: - Core Data Saving and Undo support

    @IBAction func saveAction(_ sender: AnyObject?) {
        // Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
        let context = persistentContainer.viewContext

        if !context.commitEditing() {
            NSLog("\(NSStringFromClass(type(of: self))) unable to commit editing before saving")
        }
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Customize this code block to include application-specific recovery steps.
                let nserror = error as NSError
                NSApplication.shared.presentError(nserror)
            }
        }
    }

    func windowWillReturnUndoManager(window: NSWindow) -> UndoManager? {
        // Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
        return persistentContainer.viewContext.undoManager
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Save changes in the application's managed object context before the application terminates.
        let context = persistentContainer.viewContext
        
        if !context.commitEditing() {
            NSLog("\(NSStringFromClass(type(of: self))) unable to commit editing to terminate")
            return .terminateCancel
        }
        
        if !context.hasChanges {
            return .terminateNow
        }
        
        do {
            try context.save()
        } catch {
            let nserror = error as NSError

            // Customize this code block to include application-specific recovery steps.
            let result = sender.presentError(nserror)
            if (result) {
                return .terminateCancel
            }
            
            let question = NSLocalizedString("Could not save changes while quitting. Quit anyway?", comment: "Quit without saves error question message")
            let info = NSLocalizedString("Quitting now will lose any changes you have made since the last successful save", comment: "Quit without saves error question info");
            let quitButton = NSLocalizedString("Quit anyway", comment: "Quit anyway button title")
            let cancelButton = NSLocalizedString("Cancel", comment: "Cancel button title")
            let alert = NSAlert()
            alert.messageText = question
            alert.informativeText = info
            alert.addButton(withTitle: quitButton)
            alert.addButton(withTitle: cancelButton)
            
            let answer = alert.runModal()
            if answer == .alertSecondButtonReturn {
                return .terminateCancel
            }
        }
        // If we got here, it is time to quit.
        return .terminateNow
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
