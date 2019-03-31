//
//  EventMonitor.swift
//  magicScrollWheel
//
//  Created by Aleksandr Kozhevnikov on 31/03/2019.
//  Copyright © 2019 Aleksandr Kozhevnikov. All rights reserved.
//


import Cocoa

public class EventMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void
    
    var delegate: AppDelegate?
    
    
    private var eventQueue = DispatchQueue(label: "eventQueue")
    
    public init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }
    
    deinit {
        print("deinit\n")
        stop()
    }
    //  CGEventTapProxy, CGEventType, CGEvent, UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>?
    let eventCallback: CGEventTapCallBack = { (proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) in
        
        let event: CGEvent = event
        
        //   print(event1.get)
        //      return Unmanaged.passRetained(event)
        
        
        if(event.getIntegerValueField(.scrollWheelEventIsContinuous) == 0){
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "systemScrollEventNotification"), object: nil, userInfo: ["event": event])
            
            return nil
        } else {
            
            return Unmanaged.passRetained(event)
        }
        
    }
    
    
    
    public func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
        
        eventQueue.sync {
            let eventMask: CGEventMask = (1 << CGEventType.scrollWheel.rawValue)
            guard let eventTap = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: eventMask, callback: self.eventCallback, userInfo: nil) else {
                print("Couldn't create event tap!");
                return
            }
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
            CFRunLoopRun()
        }
        
    }
    
    public func stop() {
        if monitor != nil {
            NSEvent.removeMonitor(monitor!)
            monitor = nil
        }
        
    }
}


