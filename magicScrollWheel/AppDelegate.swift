//
//  AppDelegate.swift
//  magicScrollWheel
//
//  Created by Aleksandr Kozhevnikov on 31/03/2019.
//  Copyright © 2019 Aleksandr Kozhevnikov. All rights reserved.
//


import Foundation
import IOKit.hid
import Cocoa
import CoreGraphics



@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
    var magicScrollController: MagicScrollController?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        if let button = statusItem.button {
            button.image = NSImage(named:NSImage.Name("StatusBarButtonImage"))
            button.action = #selector(showMenuPopup)
        }
        
        magicScrollController?.run()
    }
    
    override init() {
        magicScrollController = MagicScrollController()
    }
    
    @objc func showMenuPopup() {
        print("menu should be showed")
        magicScrollController?.stop()
        magicScrollController = nil
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
     //   magicScrollController?.stop()
     //   displayLink?.cancel() // TODO
    }
    
    
}

