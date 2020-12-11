//
//  BezierView.swift
//  magicScrollWheel
//
//  Created by Aleksandr Kozhevnikov on 22/09/2019.
//  Copyright © 2019 Aleksandr Kozhevnikov. All rights reserved.
//

import AppKit
import BezierKit

@IBDesignable
class BezierView: NSView, DraggableDelegate {
    // Settings
    let settings = Settings.shared
    
    var draggables: [Draggable] = []
    var selectedDraggable: Draggable?
    var lastMouseLocation: CGPoint?
    
     override var wantsDefaultClipping: Bool {
           return false
       }
    
    func draggable(_ draggable: Draggable, didUpdateLocation location: CGPoint) {
     //   self.resetCursorRects()
  
        self.setNeedsDisplay(self.bounds)
        if let controlPointIndex = draggable.controlPointIndex {
            // TODO Refactor that
            let newX = location.x / self.bounds.width
            let newY = location.y / self.bounds.height
            if controlPointIndex == 1 {
                settings.bezierControlPoint1.x = newX
                settings.bezierControlPoint1.y = newY
            } else {
                settings.bezierControlPoint2.x = newX
                settings.bezierControlPoint2.y = newY
            }

            print(settings.bezierControlPoint1)
        }
    }
    
    func addDraggable(initialLocation location: CGPoint, radius: CGFloat, controlPointIndex: Int?) {
        let draggable = Draggable(initialLocation: location, radius: radius, controlPointIndex: controlPointIndex)
        draggable.delegate = self
        self.draggables.append(draggable)
    }
    
    @IBInspectable var backgroundColor: NSColor = .clear {
        didSet {
            layer?.backgroundColor = backgroundColor.cgColor
        }
    }
//    var bezierControlPoint1 = CGPoint.init(x: 0.3, y: 0.4)
//    var bezierControlPoint2 = CGPoint.init(x: 0.37, y: 1)
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
  
        self.addDraggable(initialLocation: CGPoint(x: 0, y: 0), radius: 0, controlPointIndex: nil)
        self.addDraggable(initialLocation: CGPoint(x: self.bounds.width * settings.bezierControlPoint1.x, y: self.bounds.height * settings.bezierControlPoint1.y), radius: 10, controlPointIndex: 1)
        self.addDraggable(initialLocation: CGPoint(x: self.bounds.width * settings.bezierControlPoint2.x, y: self.bounds.height * settings.bezierControlPoint2.y), radius: 10, controlPointIndex: 2)
        self.addDraggable(initialLocation: CGPoint(x: self.bounds.width, y: self.bounds.height), radius: 0, controlPointIndex: nil)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        let context: CGContext = NSGraphicsContext.current!.cgContext

        context.saveGState()
        context.setFillColor(NSColor.white.cgColor)
        context.fill(self.bounds)

//        context.concatenate(self.affineTransform)

        Draw.reset(context)
        var curve: BezierCurve?
        if !self.draggables.isEmpty {
            curve = CubicCurve(
                p0: self.draggables[0].location,
                p1: self.draggables[1].location,
                p2: self.draggables[2].location,
                p3: self.draggables[3].location
            )
        } else {
            curve = CubicCurve(
                p0: CGPoint(x: 0, y: 0),
                p1: CGPoint(x: 50, y: 50),
                p2: CGPoint(x: 10, y: 10),
                p3: CGPoint(x: 20, y: 20)
            )
        }
        
        Draw.drawSkeleton(context, curve: curve!)
        Draw.drawCurve(context, curve: curve!)
        context.restoreGState()
    }
    
    override func mouseDown(with event: NSEvent) {
        print("mouseDown")
        let location = self.convert(event.locationInWindow, from: PopoverViewController.freshController().view)

        for (_, d) in self.draggables.enumerated() {
            
            if d.containsLocation(location) {
        
                self.selectedDraggable = d
                return
            }
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
       
        if let draggable: Draggable = self.selectedDraggable {
            var location = self.convert(event.locationInWindow, from: PopoverViewController.freshController().view)
            if location.x > self.bounds.width {
                location.x = self.bounds.width
            } else if location.x < 0 {
                location.x = 0
            }
            if location.y > self.bounds.height {
                location.y = self.bounds.height
            } else if location.y < 0 {
                location.y = 0
            }

            draggable.updateLocation(location)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        print("mouseUp")
        NotificationCenter.default.post(name: NSNotification.Name("updateTfNeeded"), object: nil)
        self.selectedDraggable = nil
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
        override func mouseMoved(with event: NSEvent) {
    //        NSLog("mouse location \(event.locationInWindow)")
            let location = self.superview!.convert(event.locationInWindow, to: self)
            self.lastMouseLocation = location
            self.setNeedsDisplay(self.bounds)
        }

    override func mouseExited(with event: NSEvent) {
        print("mouseExited")
        self.lastMouseLocation = nil
    }

    override func prepareForInterfaceBuilder() {
        layer?.backgroundColor = backgroundColor.cgColor
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.wantsLayer = true
        self.layer?.masksToBounds = false
        layer?.backgroundColor = backgroundColor.cgColor
    }
    
}
