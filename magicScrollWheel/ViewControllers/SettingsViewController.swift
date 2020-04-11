//
//  SettingsViewController.swift
//  magicScrollWheel
//
//  Created by Aleksandr Kozhevnikov on 06/10/2019.
//  Copyright © 2019 Aleksandr Kozhevnikov. All rights reserved.
//

import Cocoa

class SettingsViewController: NSViewController, NSTextFieldDelegate {

    @IBOutlet weak var scrollDurationSlider: NSSlider!
    @IBOutlet weak var scrollDurationTextField: RoundedTextField!
    @IBOutlet weak var accelerationMultiplierTextField: RoundedTextField!
    
    @IBOutlet weak var useSystemDumpingCheckbox: NSButton!
    @IBOutlet weak var accelerationMultiplierSlider: NSSlider!
    

    @IBAction func onUseSystemDumpingChange(_ sender: NSButton) {
        Settings.shared.useBounceEffect = sender.intValue == 1
    }
    
    @IBAction func onScrollDurationChange(_ sender: Any) {
        guard let sender = sender as? NSTextField != nil ? (sender as? NSTextField) : (sender as? NSSlider) else {
            return
        }
        Settings.shared.scrollDuration = Int(sender.intValue).round50down
        scrollDurationSlider.intValue = Int32(Settings.shared.scrollDuration)
        scrollDurationTextField.intValue = Int32(Settings.shared.scrollDuration)

        NotificationCenter.default.post(name: NSNotification.Name("scrollDurationChanged"), object: nil)
    }
    
    @IBAction func onAccelerationMultiplierChange(_ sender: Any) {
        guard let sender = sender as? NSTextField != nil ? (sender as? NSTextField) : (sender as? NSSlider) else {
            return
        }
        if sender.isKind(of: NSSlider.self) {
            Settings.shared.accelerationMultiplier = Float(Double(sender.doubleValue / 100))
        } else {
            Settings.shared.accelerationMultiplier = Float(Double(sender.doubleValue))
        }
        Settings.shared.accelerationMultiplier =  Float(Double(round(10 * Settings.shared.accelerationMultiplier) / 10))
        print(Settings.shared.accelerationMultiplier)
        accelerationMultiplierSlider.intValue = Int32(Settings.shared.accelerationMultiplier * 100)
        accelerationMultiplierTextField.doubleValue = Double(Settings.shared.accelerationMultiplier)
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
