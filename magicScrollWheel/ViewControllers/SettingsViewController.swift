//
//  SettingsViewController.swift
//  magicScrollWheel
//
//  Created by Aleksandr Kozhevnikov on 06/10/2019.
//  Copyright © 2019 Aleksandr Kozhevnikov. All rights reserved.
//

import Cocoa

class SettingsViewController: NSViewController, NSTextFieldDelegate {
    
    let settings = Settings.shared
    
    @IBOutlet weak var scrollDurationTextField: RoundedTextField!
    
    @IBOutlet weak var useSystemDumpingCheckbox: NSButton!
    

    @IBAction func onUseSystemDumpingChange(_ sender: NSButton) {
        settings.useSystemDamping = sender.intValue == 1
    }
    @IBAction func onEmitateTrackpadTaleChange(_ sender: NSButton) {
        settings.emitateTrackpadTale = sender.intValue == 1
    }
    
    @IBAction func onScrollDurationChange(_ sender: NSTextField) {
        settings.scrollDuration = Int(sender.intValue)
        NotificationCenter.default.post(name: NSNotification.Name("scrollDurationChanged"), object: nil)
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        useSystemDumpingCheckbox.integerValue = settings.useSystemDamping.hashValue
        scrollDurationTextField.delegate = self;
        scrollDurationTextField.stringValue = String(settings.scrollDuration)
    }
    
}
