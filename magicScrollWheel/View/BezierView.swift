//
//  BezierView.swift
//  magicScrollWheel
//
//  Created by Aleksandr Kozhevnikov on 22/09/2019.
//  Copyright © 2019 Aleksandr Kozhevnikov. All rights reserved.
//

import Cocoa

@IBDesignable
class BezierView: NSView {

    @IBInspectable var backgroundColor: NSColor = .clear {
        didSet {
            layer?.backgroundColor = backgroundColor.cgColor
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.wantsLayer = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // Drawing code here.
    }

    override func prepareForInterfaceBuilder() {
        layer?.backgroundColor = backgroundColor.cgColor
    }
    
    override func awakeFromNib() {
        layer?.backgroundColor = backgroundColor.cgColor
    }
    
}
