//
//  PopoverViewController.swift
//  magicScrollWheel
//
//  Created by Aleksandr Kozhevnikov on 15/09/2019.
//  Copyright © 2019 Aleksandr Kozhevnikov. All rights reserved.
//

import Cocoa

class PopoverViewController: NSViewController {

    
    @IBAction func quitButtonPressed(_ sender: NSButton) {
        NSApplication.shared.terminate(self)
    }
    
    @IBAction func pauseButtonPressed(_ sender: NSButton) {
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
         _ = appDelegate.toggleMagicScroll() // let isRunned = 
    }
    
    @IBAction func okButtonPressed(_ sender: NSButton) {
       let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.popover.performClose(self)
    }
    
    @IBOutlet weak var durationTF: RoundedTextField!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    // Storyboard instantiation
    static func freshController() -> PopoverViewController {
        let storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
        let identifier = NSStoryboard.SceneIdentifier("PopoverViewController")
        guard let vc = storyboard.instantiateController(withIdentifier: identifier) as? PopoverViewController else {
            fatalError("Why cant i find QuotesViewController? - Check Main.storyboard")
        }
        return vc
    }
    
}
