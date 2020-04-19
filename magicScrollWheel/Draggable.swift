//
//  Draggable.swift
//  BezierKit
//
//  Created by Holmes Futrell on 11/3/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import Foundation
import BezierKit

typealias DraggableCallback = (_ dragPosition: CGPoint) -> (CGPoint)

protocol DraggableDelegate: class {
    func draggable(_ draggable: Draggable, didUpdateLocation location: CGPoint)
}

class Draggable {

    private(set) public var location: CGPoint
    public weak var delegate: DraggableDelegate?
    private let callback: DraggableCallback
    public let radius: CGFloat
    public let controlPointIndex: Int?

    public init(initialLocation location: CGPoint, radius: CGFloat, controlPointIndex: Int?, callback: @escaping DraggableCallback) {
        self.location = location
        self.radius = radius
        self.callback = callback
        self.controlPointIndex = controlPointIndex
    }
    public convenience init(initialLocation location: CGPoint, radius: CGFloat, controlPointIndex: Int?) {
        let callback: DraggableCallback = { (dragPosition: CGPoint) -> (CGPoint) in
            return dragPosition
        }
        self.init(initialLocation: location, radius: radius, controlPointIndex: controlPointIndex, callback: callback)
    }
    
    public convenience init(initialLocation location: CGPoint, radius: CGFloat) {
     
        self.init(initialLocation: location, radius: radius, controlPointIndex: nil)
    }
    
    public func updateLocation(_ location: CGPoint) {
        let updatedLocation = self.callback(location)
        if self.location.equalTo(updatedLocation) == false {
            self.location = updatedLocation
            self.delegate!.draggable(self, didUpdateLocation: updatedLocation)
        }
    }
    public func containsLocation(_ location: CGPoint) -> Bool {
        let c = self.cursorRect as CGRect
        print("c", c)
        print("CGPoint", CGPoint(x: location.x, y: location.y))
        return c.contains(CGPoint(x: location.x, y: location.y))
    }
    public var cursorRect: NSRect {
        let r = self.radius
        let r2 = 2.0 * r
        return CGRect( origin: CGPoint(x: self.location.x - r, y: self.location.y - r),
                       size: CGSize(width: r2, height: r2))
    }

}
