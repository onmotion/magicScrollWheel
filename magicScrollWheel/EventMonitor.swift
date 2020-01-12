//
//  EventMonitor.swift
//  magicScrollWheel
//
//  Created by Aleksandr Kozhevnikov on 31/03/2019.
//  Copyright © 2019 Aleksandr Kozhevnikov. All rights reserved.
//


import Cocoa
import EventKit

public class EventMonitor {
    
    private var eventMonitorSerialQueue = DispatchQueue(label: "eventMonitorSerialQueue", qos: .userInteractive, attributes: .concurrent)
    
    var scrollEventHandler: ((CGEvent) -> ())?
    var mouseMoveEventHandler: ((CGEvent) -> ())?
    private var scrollRunLoopSource: CFRunLoopSource?
    private var mouseMoveRunLoopSource: CFRunLoopSource?
    private var runLoop = CFRunLoopGetCurrent()
    
    private let scrollEventRunLoopCallback: CGEventTapCallBack = { (proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>?  in
        
        if(event.getDoubleValueField(.scrollWheelEventIsContinuous) != 1){ // Non Continuous event (like simple mouse)
            DispatchQueue.main.async {
                MagicScrollController.shared.systemScrollEventHandler(event: event.copy()!)
            }
            
//            print("""
//                mouseEventSubtype: \(event.getIntegerValueField(.mouseEventSubtype))
//                mouseEventNumber: \(event.getDoubleValueField(.mouseEventNumber))
//                mouseEventClickState: \(event.getDoubleValueField(.mouseEventClickState))
//                mouseEventPressure: \(event.getDoubleValueField(.mouseEventPressure))
//                mouseEventButtonNumber: \(event.getDoubleValueField(.mouseEventButtonNumber))
//                mouseEventDeltaX: \(event.getDoubleValueField(.mouseEventDeltaX))
//                mouseEventDeltaY: \(event.getDoubleValueField(.mouseEventDeltaY))
//                mouseEventInstantMouser: \(event.getDoubleValueField(.mouseEventInstantMouser))
//                mouseEventSubtype: \(event.getDoubleValueField(.mouseEventSubtype))
//                mouseEventWindowUnderMousePointer: \(event.getDoubleValueField(.mouseEventWindowUnderMousePointer))
//                scrollWheelEventDeltaAxis1: \(event.getDoubleValueField(.scrollWheelEventDeltaAxis1))
//                scrollWheelEventDeltaAxis2: \(event.getDoubleValueField(.scrollWheelEventDeltaAxis2))
//                scrollWheelEventPointDeltaAxis1: \(event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1))
//                scrollWheelEventPointDeltaAxis2: \(event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2))
//                scrollWheelEventFixedPtDeltaAxis1: \(event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1))
//                """)
          //  return Unmanaged.passUnretained(event)
            return nil
        } else {
            #if DEBUG
            autoreleasepool{
                print(NSEvent(cgEvent: event.copy()!)!, "\n_____________________________________________\n") //possible memory leaks wo using autoreleasepool
            }
            #endif
            
            return Unmanaged.passUnretained(event)
        }
        
    }
    
    let mouseMoveEventRunLoopCallback: CGEventTapCallBack = { (proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>?  in
        
        MagicScrollController.shared.mouseEventHandler(event: event.copy()!)
        // NotificationCenter.default.post(name: NSNotification.Name(rawValue: "mouseMovedEventNotification"), object: nil, userInfo: ["event": evt])
        return Unmanaged.passUnretained(event)
        
    }
    
    private func createEvantTap(forEventMask eventMask: CGEventMask, withOptions options: CGEventTapOptions = .defaultTap, callback: @escaping CGEventTapCallBack) -> CFMachPort? {
        
        guard let eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: options, eventsOfInterest: eventMask, callback: callback, userInfo: nil) else {
            
            print("Couldn't create event tap!");
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.alertStyle = NSAlert.Style.critical
                alert.informativeText = "You must grant accessibility control for this app"
                alert.messageText = "Accessibility Control access request"
                alert.addButton(withTitle: "Open Preferences")
                alert.addButton(withTitle: "Cancel")
                
                let modalAction = alert.runModal()
                
                if (modalAction == NSApplication.ModalResponse.alertFirstButtonReturn) {
                    let prefpaneUrl = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                    NSWorkspace.shared.open(prefpaneUrl)
                }
            }
           
            return nil
        }
        
        return eventTap
    }
    
    
    public func start() {
        
        eventMonitorSerialQueue.async {
            self.runLoop = CFRunLoopGetCurrent()
            
            /// Run Loop for mouse events
            let scrollEventMask: CGEventMask = (1 << CGEventType.scrollWheel.rawValue)
            let mouseMoveEventMasks: [CGEventMask] = [(1 << CGEventType.mouseMoved.rawValue)
                , (1 << CGEventType.leftMouseDragged.rawValue)
                , (1 << CGEventType.rightMouseDragged.rawValue)
                , (1 << CGEventType.otherMouseDragged.rawValue)
                , (1 << CGEventType.flagsChanged.rawValue)]
            var mouseMoveEventMask: CGEventMask = 0b0
            mouseMoveEventMasks.forEach( { item in
                mouseMoveEventMask = mouseMoveEventMask | item
            })
            
            if let scrollEventTap = self.createEvantTap(forEventMask: scrollEventMask, callback: self.scrollEventRunLoopCallback) {
                self.scrollRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, scrollEventTap, 0)
                CFRunLoopAddSource(self.runLoop, self.scrollRunLoopSource, .commonModes)
                CGEvent.tapEnable(tap: scrollEventTap, enable: true)
            }
            if let mouseMoveEventTap = self.createEvantTap(forEventMask: mouseMoveEventMask, withOptions: .listenOnly, callback: self.mouseMoveEventRunLoopCallback) {
                self.mouseMoveRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, mouseMoveEventTap, 0)
                CFRunLoopAddSource(self.runLoop, self.mouseMoveRunLoopSource, .commonModes)
                CGEvent.tapEnable(tap: mouseMoveEventTap, enable: true)
            }
            
            
            print("CFRunLoopRun")
            CFRunLoopRun()
            print("CFRunLoopStop")
        }
        //  print("CFRunLoopRun")
        //  CFRunLoopRun()
        
    }
    
    public func stop() {
        print("stop EventMonitor\n")
        
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
    
    init() {
        print("init EventMonitor")
    }
    
    deinit {
        print("deinit EventMonitor\n")
    }
}


