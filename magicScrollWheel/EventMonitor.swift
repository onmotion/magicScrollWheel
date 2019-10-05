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
    
    var scrollEventHandler: ((CGEvent) -> ())?
    var mouseMoveEventHandler: ((CGEvent) -> ())?
    private var scrollRunLoopSource: CFRunLoopSource?
    private var mouseMoveRunLoopSource: CFRunLoopSource?
    private let runLoop = CFRunLoopGetCurrent()
    
    private var eventQueue = DispatchQueue(label: "eventQueue", qos: .userInitiated)
    
    
    
    private let scrollEventRunLoopCallback: CGEventTapCallBack = { (proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>?  in
        
        print("eventCallback")
        let evt: CGEvent = event.copy()!
        
        if(evt.getDoubleValueField(.scrollWheelEventIsContinuous) != 1){
            MagicScrollController.shared.systemScrollEventHandler(event: evt)
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
            return Unmanaged.passRetained(evt)
        }
        
    }
    
    let mouseMoveEventRunLoopCallback: CGEventTapCallBack = { (proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>?  in
        
        let evt: CGEvent = event.copy()!
    MagicScrollController.shared.mouseEventHandler(event: evt)
       // NotificationCenter.default.post(name: NSNotification.Name(rawValue: "mouseMovedEventNotification"), object: nil, userInfo: ["event": evt])
        return Unmanaged.passRetained(evt)
        
    }
    
    private func createEvantTap(forEventMask eventMask: CGEventMask, withOptions options: CGEventTapOptions = .defaultTap, callback: @escaping CGEventTapCallBack) -> CFMachPort? {

        guard let eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: options, eventsOfInterest: eventMask, callback: callback, userInfo: nil) else {
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
            return nil
        }
        
        return eventTap
    }
    
    
    public func start() {
        /// Handling mouse events with masks such as: [.scrollWheel, .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        //    monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
        
        /// Run Loop for mouse events
        let scrollEventMask: CGEventMask = (1 << CGEventType.scrollWheel.rawValue)
        let mouseMoveEventMask: CGEventMask = (1 << CGEventType.mouseMoved.rawValue)
            ^ (1 << CGEventType.leftMouseDragged.rawValue)
            ^ (1 << CGEventType.rightMouseDragged.rawValue)
            ^ (1 << CGEventType.otherMouseDragged.rawValue)

        
        if let scrollEventTap = self.createEvantTap(forEventMask: scrollEventMask, callback: scrollEventRunLoopCallback) {
            self.scrollRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, scrollEventTap, 0)
            CFRunLoopAddSource(self.runLoop, self.scrollRunLoopSource, .commonModes)
            CGEvent.tapEnable(tap: scrollEventTap, enable: true)
        }
        if let mouseMoveEventTap = self.createEvantTap(forEventMask: mouseMoveEventMask, withOptions: .listenOnly, callback: mouseMoveEventRunLoopCallback) {
            self.mouseMoveRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, mouseMoveEventTap, 0)
            CFRunLoopAddSource(self.runLoop, self.mouseMoveRunLoopSource, .commonModes)
            CGEvent.tapEnable(tap: mouseMoveEventTap, enable: true)
        }
        
        //  print("CFRunLoopRun")
        //  CFRunLoopRun()
        
    }
    
    public func stop() {
        print("stop EventMonitor\n")
        if monitor != nil {
            NSEvent.removeMonitor(monitor!)
            monitor = nil
        }
        DispatchQueue.main.async {
            if self.scrollRunLoopSource != nil {
                CFRunLoopRemoveSource(self.runLoop, self.scrollRunLoopSource, .commonModes)
            }
            if self.mouseMoveRunLoopSource != nil {
                CFRunLoopRemoveSource(self.runLoop, self.mouseMoveRunLoopSource, .commonModes)
            }
         
            CFRunLoopStop(self.runLoop)
        }
        
    }
    
    deinit {
        print("deinit EventMonitor\n")
    }
}


