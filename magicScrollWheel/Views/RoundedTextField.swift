//
//  RoundedTextField.swift
//  magicScrollWheel
//
//  Created by Aleksandr Kozhevnikov on 22/09/2019.
//  Copyright © 2019 Aleksandr Kozhevnikov. All rights reserved.
//

import Cocoa

@IBDesignable class RoundedTextField: NSTextField {
    
    @IBInspectable var cornerRadius: CGFloat = 5.0
    @IBInspectable var borderColor: NSColor = .lightGray

    override func draw(_ dirtyRect: NSRect) {
        self.wantsLayer = true
        self.layer?.borderColor = borderColor.cgColor
        self.layer?.borderWidth = 1
        self.layer?.masksToBounds = true;
        self.layer?.cornerRadius = cornerRadius;
        
        super.draw(dirtyRect)
    }
}
