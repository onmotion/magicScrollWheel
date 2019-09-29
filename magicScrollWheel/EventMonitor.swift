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
    private let runLoop = CFRunLoopGetCurrent()
    
    private var eventQueue = DispatchQueue(label: "eventQueue", qos: .userInteractive)
    
    public init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
        print("init EventMonitor\n")
    }
    
    deinit {
        print("deinit EventMonitor\n")
    }
    
    let eventCallback: CGEventTapCallBack = { (proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>?  in
        //  print("event callback")
        let evt: CGEvent = event.copy()!
        
        //     NotificationCenter.default.post(name: NSNotification.Name(rawValue: "systemScrollEventNotification"), object: nil, userInfo: ["event": evt])
        //
        //    print( NSEvent.init(cgEvent: evt))
        
        //        print(evt.getDoubleValueField(.mouseEventDeltaY))
        //   print(evt.getDoubleValueField(.scrollWheelEventIsContinuous))
        //        print(evt.getDoubleValueField(.scrollWheelEventDeltaAxis1))
        //        print(evt.getDoubleValueField(.scrollWheelEventPointDeltaAxis1))
        //        print(evt.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1))
        //
        //        return Unmanaged.passRetained(evt)
        
        if(evt.getDoubleValueField(.scrollWheelEventIsContinuous) != 1){
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "systemScrollEventNotification"), object: nil, userInfo: ["event": evt])
            //  return Unmanaged.passRetained(evt)
            print("""
                mouseEventSubtype: \(evt.getIntegerValueField(.mouseEventSubtype))
                mouseEventNumber: \(evt.getDoubleValueField(.mouseEventNumber))
                mouseEventClickState: \(evt.getDoubleValueField(.mouseEventClickState))
                mouseEventPressure: \(evt.getDoubleValueField(.mouseEventPressure))
                mouseEventButtonNumber: \(evt.getDoubleValueField(.mouseEventButtonNumber))
                mouseEventDeltaX: \(evt.getDoubleValueField(.mouseEventDeltaX))
                mouseEventDeltaY: \(evt.getDoubleValueField(.mouseEventDeltaY))
                mouseEventInstantMouser: \(evt.getDoubleValueField(.mouseEventInstantMouser))
                mouseEventSubtype: \(evt.getDoubleValueField(.mouseEventSubtype))
                mouseEventWindowUnderMousePointer: \(evt.getDoubleValueField(.mouseEventWindowUnderMousePointer))
                mouseEventWindowUnderMousePointerThatCanHandleThisEvent: \(evt.getDoubleValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent))
                """)
            
            return nil
        } else {
            //   NotificationCenter.default.post(name: NSNotification.Name(rawValue: "magicScrollEventNotification"), object: nil, userInfo: ["event": evt])
            
            return Unmanaged.passRetained(evt)
        }
        
    }
    
    
    
    public func start() {
        /// Handling mouse events with masks such as: [.scrollWheel, .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
        
        /// Run Loop for scrollWheel event
        let eventMask: CGEventMask = (1 << CGEventType.scrollWheel.rawValue)
        DispatchQueue.main.async {
            //   eventQueue.async {
            guard let eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: eventMask, callback: self.eventCallback, userInfo: nil) else {
                print("Couldn't create event tap!");
                let alert = NSAlert()
                alert.alertStyle = NSAlert.Style.critical
                alert.informativeText = "You must grant accessibility control for this app"
                alert.messageText = "Couldn't create event tap"
                alert.addButton(withTitle: "Open Preferences")
                alert.addButton(withTitle: "Cancel")
                
                let modalAction = alert.runModal()
                if (modalAction == NSApplication.ModalResponse.alertFirstButtonReturn) {
                    let prefpaneUrl = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                    NSWorkspace.shared.open(prefpaneUrl)
                }
                return
            }
            
            
            self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            CFRunLoopAddSource(self.runLoop, self.runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
            print("CFRunLoopRun")
            CFRunLoopRun()
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


