//
//  SettingsViewController.swift
//  magicScrollWheel
//
//  Created by Aleksandr Kozhevnikov on 06/10/2019.
//  Copyright © 2019 Aleksandr Kozhevnikov. All rights reserved.
//

import Cocoa

class SettingsViewController: NSViewController, NSTextFieldDelegate {

    
    @IBOutlet weak var scrollDurationTextField: RoundedTextField!
    @IBOutlet weak var accelerationMultiplierTextField: RoundedTextField!
    
    @IBOutlet weak var useSystemDumpingCheckbox: NSButton!
    

    @IBAction func onUseSystemDumpingChange(_ sender: NSButton) {
        Settings.shared.useBounceEffect = sender.intValue == 1
    }
    @IBAction func onEmitateTrackpadTaleChange(_ sender: NSButton) {
        Settings.shared.emitateTrackpadTale = sender.intValue == 1
    }
    
    @IBAction func onScrollDurationChange(_ sender: NSTextField) {
        Settings.shared.scrollDuration = Int(sender.intValue)
        NotificationCenter.default.post(name: NSNotification.Name("scrollDurationChanged"), object: nil)
    }
    
    @IBAction func onAccelerationMultiplierChange(_ sender: NSTextField) {
        Settings.shared.accelerationMultiplier = Double(sender.doubleValue)
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        useSystemDumpingCheckbox.integerValue = Settings.shared.useBounceEffect ? 1 : 0
        scrollDurationTextField.delegate = self;
        scrollDurationTextField.stringValue = String(Settings.shared.scrollDuration)
        accelerationMultiplierTextField.stringValue = String(Settings.shared.accelerationMultiplier)
    }
    
}
