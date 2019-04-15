//
//  AppDelegate.swift
//  magicScrollWheel
//
//  Created by Aleksandr Kozhevnikov on 31/03/2019.
//  Copyright © 2019 Aleksandr Kozhevnikov. All rights reserved.
//


import Foundation
import IOKit.hid
import Cocoa
import CoreGraphics

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var accessQueue = DispatchQueue(label: "eventQueue")
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    var eventMonitor: EventMonitor?
    var startTimestamp: TimeInterval?
    var scrollDuration = 200 //ms
    var framesLeft = 0
    var maxFrames = 0
    var useSystemDamping = true;
    var damperLevel = 5 //1 - 100
    var amplifierSensitivityLevel = 80 // ms
    
    var stepSize: Int64 {
        get {
            return Int64(self.scheduledPixelsToScroll / (self.framesLeft))
        }
    }
    var pixelsToScrollTextField = 50
    var maxScheduledPixelsToScroll = 0
    
    private var resetAmplifierTask: DispatchWorkItem? = nil
    private var lastScrollWheelTime: UInt64 = DispatchTime.now().uptimeNanoseconds
    var amplifier: Double = 1 {
        didSet {
            self.resetAmplifierTask?.cancel()
            self.resetAmplifierTask = nil
            if self.amplifier > 1 {
                self.resetAmplifierTask = DispatchWorkItem { [unowned self] in
                    self.resetAmplifierTask?.cancel()
                    self.amplifier = 1
                }
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.05, execute: self.resetAmplifierTask!)
            }
            
        }
    }
    var maxAmplifierLevel = 6.0
    var amplifierStep = 2.0
    var damperFramesLeft = 0
    
    var scheduledPixelsToScroll: Int = 0{
        didSet {
            if (scheduledPixelsToScroll > self.maxScheduledPixelsToScroll || scheduledPixelsToScroll == 0) {
                self.maxScheduledPixelsToScroll = scheduledPixelsToScroll
            }
        }
    }
    
    private var _deltaY: Double = 0
    var deltaY: Double {
        get {
            return Double(Int(self._deltaY) * direction)
        }
        set(val) {
            self._deltaY = abs(val)
        }
    }
    var prevDeltaY: Double = 0
    
    var currentLocation: CGPoint?
    var isShiftPressed = false;
    var direction = 1 {
        willSet{
            if newValue != direction {
              //  print("direction changed ", direction)
                self.amplifier = 1
                self.currentPhase = 1
                self.currentSubphase = 11
                self.scheduledPixelsToScroll = 0
                self.prevDeltaY = 0
            }
        }
    }
    var timer: Timer?
    
    var currentPhase: Int64 = 0
    var currentSubphase: Int64 = 11
    
    
    @objc func onSystemScrollEvent(notification:Notification)
    {
        let event: CGEvent = notification.userInfo!["event"] as! CGEvent
        self.direction = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) < 0 ? -1 : 1
        self.damperFramesLeft = self.damperLevel
        
        if self.currentPhase == 1{
            // self.framesLeft = self.maxFrames - 2
            self.framesLeft = self.maxFrames
            if (UInt64(DispatchTime.now().uptimeNanoseconds) - lastScrollWheelTime) / 1_000_000 < self.amplifierSensitivityLevel {
                if self.amplifier < self.maxAmplifierLevel {
                    self.amplifier += log2(self.amplifier + self.amplifierStep)
                }
            }
            self.lastScrollWheelTime = DispatchTime.now().uptimeNanoseconds
        } else if self.currentPhase == 2{
            self.framesLeft = self.maxFrames
            self.currentPhase = 1
            self.currentSubphase = 11
        } else {
            self.framesLeft = self.maxFrames
            self.currentPhase = 1
        }
        
        self.scheduledPixelsToScroll += self.pixelsToScrollTextField * Int(self.amplifier)
    }
    
    @objc func runInterval() {
        
        accessQueue.async {
           
            guard let location = self.currentLocation, self.framesLeft > 0 else {
                self.scheduledPixelsToScroll = 0
                return
            }
            
            let absPrevDeltaY = abs(self.prevDeltaY)
            let absDeltaY = abs(self.deltaY)
            
            if self.framesLeft == 1 {
                self.deltaY = 0
                self.prevDeltaY = 0
            } else {
                self.deltaY = Double(self.stepSize)
                
                if self.framesLeft == Int(Double(self.maxFrames) / 2) {
                    self.currentPhase = 2
                    self.deltaY = self.prevDeltaY
                } else if self.framesLeft < Int(Double(self.maxFrames) / 2) {
                   // print("self.framesLeft < Int(Double(self.maxFrames) / 2)")
                    self.currentPhase = 2
                    
                    if absPrevDeltaY > 1 {
                        let prevDeltaY = Double(absPrevDeltaY)
                        if Int(absPrevDeltaY) < self.damperLevel {
                            self.deltaY = prevDeltaY - log10(prevDeltaY)
                        } else {
                          //  self.deltaY = absPrevDeltaY - Double(absPrevDeltaY) / Double(self.framesLeft)
                            self.deltaY = prevDeltaY - log2(prevDeltaY)
                        }
                        
                    } else {
                        self.deltaY = 0
                    }
                } else {
                    // acceleration
                    if absPrevDeltaY > absDeltaY {
                        self.deltaY = self.prevDeltaY
                    }
                }
                self.prevDeltaY = self.deltaY
            }
       
            let ev = CGEvent.init(source: nil)
            ev?.type = .scrollWheel
            ev?.setDoubleValueField(.scrollWheelEventIsContinuous, value: 1)
            ev?.location = location
            ev?.setIntegerValueField(.eventSourceUserData, value: 1)
            
//            print("self.currentPhase = ", self.currentPhase)
//            print("self.currentSubphase = ", self.currentSubphase)
            
            if !self.useSystemDamping && self.framesLeft == 1 {
                ev?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 3)
            } else if self.currentPhase == 0  {
                ev?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 3)
                ev?.setIntegerValueField(.scrollWheelEventScrollPhase, value: 4)
                self.deltaY = 0
                self.currentPhase = 1
                self.currentSubphase = 11
            } else if self.currentPhase == 1 {
                if self.currentSubphase == 11 {
                    ev?.setIntegerValueField(.scrollWheelEventScrollPhase, value: 1)
                    self.currentSubphase = 12
                } else if self.currentSubphase == 12 {
//                    self.deltaY = round(abs(self.deltaY) + log2(abs(self.deltaY)))
//                    self.prevDeltaY = self.deltaY
                    ev?.setIntegerValueField(.scrollWheelEventScrollPhase, value: 2)
                } else {
                    self.currentSubphase = 12
                }
            } else {
                if self.currentSubphase == 12 {
                    ev?.setIntegerValueField(.scrollWheelEventScrollPhase, value: 4)
                    ev?.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: 0)
                    ev?.post(tap:.cghidEventTap)
                    self.currentSubphase = 22
                    ev?.setIntegerValueField(.scrollWheelEventScrollPhase, value: 0)
                    ev?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 1)
                } else {
                    ev?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 2)
                }
                
            }
          //  print("deltaY - ", self.deltaY)
            
            ev?.setDoubleValueField(self.isShiftPressed
                ? .scrollWheelEventPointDeltaAxis2
                : .scrollWheelEventPointDeltaAxis1, value: self.deltaY)
            
            // scroll in launchpad
            ev?.setIntegerValueField(.scrollWheelEventFixedPtDeltaAxis1, value: Int64(self.deltaY))
            
            ev?.post(tap:.cghidEventTap)
            
            if self.scheduledPixelsToScroll >= abs(Int(self.deltaY)) {
                self.scheduledPixelsToScroll -= abs(Int(self.deltaY))
            }
            if !(self.framesLeft == 2 && absDeltaY > 1) {
                self.framesLeft -= 1
            }
            
        }
    }
    
    func mouseEventHandler(event: NSEvent?) {
        
        if (event?.type == .mouseMoved) {
            self.currentLocation = event?.cgEvent?.location
            return
        }
        self.isShiftPressed = (event?.modifierFlags.contains(.shift))!
        //    print(event!)
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        self.timer = Timer.scheduledTimer(timeInterval: 0.016, target: self, selector: #selector(runInterval), userInfo: nil, repeats: true)
        
        NotificationCenter.default.addObserver(self, selector: #selector(onSystemScrollEvent(notification:)), name: NSNotification.Name(rawValue: "systemScrollEventNotification"), object: nil)
        
        self.maxFrames = Int(self.scrollDuration / 16)
        eventMonitor = EventMonitor(mask: [.scrollWheel, .mouseMoved],  handler: mouseEventHandler)
        eventMonitor?.start()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    
}

