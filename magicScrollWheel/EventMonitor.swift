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
    
    
    private var eventQueue = DispatchQueue(label: "eventQueue", qos: .background, attributes: .concurrent)
    
    public init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }
    
    deinit {
        print("deinit\n")
        stop()
    }
    //  CGEventTapProxy, CGEventType, CGEvent, UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>?
    let eventCallback: CGEventTapCallBack = { (proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>?  in
      //  print("event callback")
        
        
        let evt: CGEvent = event.copy()!
  
//        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "systemScrollEventNotification"), object: nil, userInfo: ["event": evt])
//
//        print( evt)

//        print(evt.getDoubleValueField(.mouseEventDeltaY))
//        print(evt.getDoubleValueField(.scrollWheelEventDeltaAxis1))
//        print(evt.getDoubleValueField(.scrollWheelEventPointDeltaAxis1))
//        print(evt.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1))
     //   return Unmanaged.passRetained(evt)

        if(evt.getIntegerValueField(.scrollWheelEventIsContinuous) == 0){
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "systemScrollEventNotification"), object: nil, userInfo: ["event": evt])
            
            return nil
        } else {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "magicScrollEventNotification"), object: nil, userInfo: ["event": evt])
            
            return Unmanaged.passRetained(evt)
        }
        
    }
    
    
    
    public func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
        
      //  eventQueue.async {
            let eventMask: CGEventMask = (1 << CGEventType.scrollWheel.rawValue)
            guard let eventTap = CGEvent.tapCreate(tap: .cghidEventTap, place: .tailAppendEventTap, options: .defaultTap, eventsOfInterest: eventMask, callback: self.eventCallback, userInfo: nil) else {
                print("Couldn't create event tap!");
                return
            }
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
            CFRunLoopRun()
     //   }
        
    }
    
    public func stop() {
        if monitor != nil {
            NSEvent.removeMonitor(monitor!)
            monitor = nil
        }
        
    }
}


