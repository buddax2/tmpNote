//
//  AppDelegate.swift
//  LauncherApplication
//
//  Created by BUDDAx2 on 9/25/17.
//  Copyright © 2017 BUDDAx2. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {



    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        NSLog("launched tmpNote launcher")
        
        let mainAppIdentifier = Bundle.main.bundleIdentifier!.replacingOccurrences(of: ".LauncherApplication", with: "")
        let runningApps = NSWorkspace.shared.runningApplications
        var alreadyRunning = false
        
        for app in runningApps {
            if app.bundleIdentifier == mainAppIdentifier {
                alreadyRunning = true
                break
            }
        }
        
        if alreadyRunning == false {
            DistributedNotificationCenter.default().addObserver(self, selector: #selector(terminate), name: Notification.Name(rawValue: "killme"), object: mainAppIdentifier)
            
            let path = Bundle.main.bundlePath as NSString
            var components = path.pathComponents
            components.removeLast()
            components.removeLast()
            components.removeLast()
            components.append("MacOS")
            components.append("tmpNote")
            let newPath = NSString.path(withComponents: components)
            NSWorkspace.shared.launchApplication(newPath)
        }
        else {
            terminate()
        }
        
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    @objc func terminate() {
        NSApp.terminate(self)
    }

}

