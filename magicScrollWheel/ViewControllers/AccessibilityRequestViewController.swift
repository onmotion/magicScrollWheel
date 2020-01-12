//
//  AccessibilityRequestViewController.swift
//  magicScrollWheel
//
//  Created by Aleksandr Kozhevnikov on 12.01.2020.
//  Copyright © 2020 Aleksandr Kozhevnikov. All rights reserved.
//

import Cocoa

class AccessibilityRequestViewController: NSViewController, NSWindowDelegate {

    var timer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        timer = Timer.scheduledTimer(
            timeInterval: 0.5,
            target: self,
            selector: #selector(checkAccess),
            userInfo: nil,
            repeats: true
        )
    }
    
    override func viewDidAppear() {
        self.view.window?.delegate = self
        self.view.window?.center()
    }
    
    func windowWillClose(_ notification: Notification) {
        if !AXIsProcessTrusted() {
            NSApplication.shared.terminate(self)
        }
    }
    
    @objc func checkAccess() {
    
        if AXIsProcessTrusted() {
            timer?.invalidate()
            timer = nil
            self.view.window?.close()
            (NSApplication.shared.delegate as! AppDelegate).startApp()
        }
    }
    
    @IBAction func onGrantButtonClick(_ sender: NSButton) {
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
    }
    
}
