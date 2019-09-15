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
    private var runLoopSource: CFRunLoopSource?
    let runLoop = CFRunLoopGetCurrent()
    
    private var eventQueue = DispatchQueue(label: "eventQueue", qos: .userInteractive)
    
    public init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
        print("init EventMonitor\n")
    }
    
    deinit {
        print("deinit EventMonitor\n")
      //  stop()
    }

    let eventCallback: CGEventTapCallBack = { (proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>?  in
      //  print("event callback")
        let evt: CGEvent = event.copy()!
  
   //     NotificationCenter.default.post(name: NSNotification.Name(rawValue: "systemScrollEventNotification"), object: nil, userInfo: ["event": evt])
//
//        print( evt)

//        print(evt.getDoubleValueField(.mouseEventDeltaY))
     //   print(evt.getDoubleValueField(.scrollWheelEventIsContinuous))
//        print(evt.getDoubleValueField(.scrollWheelEventDeltaAxis1))
//        print(evt.getDoubleValueField(.scrollWheelEventPointDeltaAxis1))
//        print(evt.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1))
//
//        return Unmanaged.passRetained(evt)

        if(evt.getDoubleValueField(.scrollWheelEventDeltaAxis1) != 0){
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "systemScrollEventNotification"), object: nil, userInfo: ["event": evt])
          //  return Unmanaged.passRetained(evt)
            return nil
        } else {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "magicScrollEventNotification"), object: nil, userInfo: ["event": evt])
            return Unmanaged.passRetained(evt)
        }
        
    }
    
    
    
    public func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
       DispatchQueue.main.async {
     //   eventQueue.async {
       
            let eventMask: CGEventMask = (1 << CGEventType.scrollWheel.rawValue)
            guard let eventTap = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: eventMask, callback: self.eventCallback, userInfo: nil) else {
                print("Couldn't create event tap!");
                return
            }
            self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            CFRunLoopAddSource(self.runLoop, self.runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
            CFRunLoopRun()
            print("CFRunLoopStop")
        }
        
    }
    
    public func stop() {
        print("stop EventMonitor\n")
        if monitor != nil {
            NSEvent.removeMonitor(monitor!)
            monitor = nil
        }
        DispatchQueue.main.async {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), self.runLoopSource, .commonModes)
            CFRunLoopStop(self.runLoop)
        }
        
    }
}


