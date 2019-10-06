//
//  SettingsViewController.swift
//  magicScrollWheel
//
//  Created by Aleksandr Kozhevnikov on 06/10/2019.
//  Copyright © 2019 Aleksandr Kozhevnikov. All rights reserved.
//

import Cocoa

class SettingsViewController: NSViewController {
    
    let settings = Settings.shared
    
    
    @IBOutlet weak var useSystemDumpingCheckbox: NSButton!
    

    @IBAction func onUseSystemDumpingChange(_ sender: NSButton) {
        settings.useSystemDamping = sender.intValue == 1

    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        useSystemDumpingCheckbox.integerValue = settings.useSystemDamping.hashValue
    }
    
}
