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
    
    private var accessQueue = DispatchQueue(label: "accessQueue", qos: .userInteractive)
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    var eventMonitor: EventMonitor?
    var startTimestamp: TimeInterval?
    var scrollDuration = 260 //ms
    var framesLeft = 0
    var maxFrames = 0
    var useSystemDamping = false;
    var damperLevel = 30 //1 - 100
    var amplifierSensitivityLevel = 80 // ms
    var log10Remainder = 0.0
    
    var displayLink: DisplayLink? = nil
    
    var stepSize: Int {
        get {
            
            return Int(round(Double(self.scheduledPixelsToScroll)) / Double(self.framesLeft))
        }
    }
    var pixelsToScrollTextField = 60
    var maxScheduledPixelsToScroll = 0
    
    private var resetAmplifierTask: DispatchWorkItem? = nil
    private var lastScrollWheelTime: UInt64 = DispatchTime.now().uptimeNanoseconds
    var lastTime: UInt64 = DispatchTime.now().uptimeNanoseconds
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
    var maxAmplifierLevel = 1.0
    var amplifierStep = 4.0
    var damperFramesLeft = 0
    
    var scheduledPixelsToScroll: Int = 0{
        didSet {
            if (scheduledPixelsToScroll > self.maxScheduledPixelsToScroll || scheduledPixelsToScroll == 0) {
                self.maxScheduledPixelsToScroll = scheduledPixelsToScroll
            }
        }
    }
    
    private var _deltaY: Int = 0
    var deltaY: Int {
        get {
            return self._deltaY * direction
        }
        set(val) {
            self._deltaY = abs(val)
        }
    }
    var prevDeltaY: Int = 0
    
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
    
    var scrollEvent: CGEvent! = CGEvent(source: nil)
    
    func postEvent(event: CGEvent, delay: UInt32 = 0) {
        guard let location = self.currentLocation else {
            return
        }
      //  DispatchQueue.main.async {
            event.location = location
            event.post(tap: .cghidEventTap)
      //  }
    }
    
    @objc func onSystemScrollEvent(notification:Notification)
    {
       // print("sys ", (UInt64(DispatchTime.now().uptimeNanoseconds) - lastTime) / 1_000_00)
        self.lastTime = DispatchTime.now().uptimeNanoseconds
        //        return
        
        self.scrollEvent = notification.userInfo!["event"] as! CGEvent
        
        self.direction = self.scrollEvent.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) < 0 ? -1 : 1
        self.damperFramesLeft = self.damperLevel
        
        if self.currentPhase == 1{
            // self.framesLeft = self.maxFrames - 2
            self.framesLeft = self.maxFrames
            if (UInt64(DispatchTime.now().uptimeNanoseconds) - lastScrollWheelTime) / 1_000_000 < self.amplifierSensitivityLevel {
                if self.amplifier < self.maxAmplifierLevel {
                    self.amplifier += round(log2(self.amplifier + self.amplifierStep) * 10) / 10
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
        
        self.scheduledPixelsToScroll += self.pixelsToScrollTextField
        
        //     sendEvent(ev: notification.userInfo!["event"] as! CGEvent)
    }
    
    @objc func onMagicScrollEvent(notification:Notification) {
      //  print((UInt64(DispatchTime.now().uptimeNanoseconds) - lastTime) / 1_000_00)
        self.lastTime = DispatchTime.now().uptimeNanoseconds
        //       sendEvent(ev: notification.userInfo!["event"] as! CGEvent)
        self.scrollEvent = notification.userInfo!["event"] as! CGEvent
    }
    
    @objc func sendEvent() {
        
        accessQueue.async {
            //   let ev = self.scrollEvent
            //  print("sleep")
            guard self.framesLeft > 0 else {
                self.scheduledPixelsToScroll = 0
                return
            }
            self.deltaY = self.stepSize
            let absPrevDeltaY = abs(self.prevDeltaY)
   
            
            if self.framesLeft == 1 {
                self.deltaY = 0
                self.prevDeltaY = 0
            } else {

                if self.framesLeft == Int(Double(self.maxFrames) / 2) {
                    self.currentPhase = 2
                    self.deltaY = self.prevDeltaY
                } else if self.framesLeft < Int(Double(self.maxFrames) / 2) { // deceleration
                    self.currentPhase = 2
                    
                    if absPrevDeltaY >= 1 {
                        let prevDeltaY = Double(absPrevDeltaY)
                        if absPrevDeltaY < self.damperLevel {
                            var log_10 = 0.0
                         //   print(prevDeltaY)
                            if prevDeltaY <= 1 {
                                 log_10 = 0.3
                            } else {
                                 log_10 = log10(prevDeltaY)
                            }
                            
                            self.log10Remainder += log_10
                         //   print(self.log10Remainder)
                            if self.log10Remainder < 1 {
                                self.deltaY = Int(prevDeltaY)
                            } else {
                                self.deltaY = Int(prevDeltaY - self.log10Remainder.rounded())
                                self.log10Remainder = 0
                            }
                         
                           // self.deltaY = Int(round(prevDeltaY - log10(prevDeltaY).rounded(.up)))
                        } else {
                            //  self.deltaY = absPrevDeltaY - Double(absPrevDeltaY) / Double(self.framesLeft)
                            self.deltaY = Int(round(prevDeltaY - log2(prevDeltaY).rounded()))
                        }
                        
                    } else {
                        self.deltaY = 0
                        self.framesLeft = 1
                    }
                } else {
                    // acceleration
                    if absPrevDeltaY > abs(self.deltaY) {
                        self.deltaY = self.prevDeltaY
                    } else {
                        if abs(self.deltaY) <= 0 {
                            self.deltaY = 0
                        } else {
                            self.deltaY = abs(self.deltaY) + Int(round(log10(Double(abs(self.deltaY))).rounded()) * self.amplifier)
                        }
                        
                        
                    }
                }
                self.prevDeltaY = self.deltaY
            }
            
            var ev = CGEvent.init(source: nil)
            ev?.type = .scrollWheel
            ev?.setDoubleValueField(.scrollWheelEventIsContinuous, value: 1)
            
            // ev?.setIntegerValueField(.scrollWheelEventScrollCount, value: 2000)
            //    ev?.setIntegerValueField(.eventSourceUserData, value: 1)
            
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
                    self.deltaY = abs(self.deltaY) + 1
                    ev?.setIntegerValueField(.scrollWheelEventScrollPhase, value: 1)
                    self.currentSubphase = 12
                } else if self.currentSubphase == 12 {
                    ev?.setIntegerValueField(.scrollWheelEventScrollPhase, value: 2)
                } else {
                    
                    self.currentSubphase = 12
                }
            } else {
                if self.currentSubphase == 12 {
                     // let endEvent = ev?.copy()
                    
                    
                    self.currentSubphase = 22
                    return
                } else if self.currentSubphase == 22 {
                    ev?.setIntegerValueField(.scrollWheelEventScrollPhase, value: 4)
                    ev?.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: 0)
                   // self.deltaY = 0
                    self.postEvent(event: ev!)
                    ev?.setIntegerValueField(.scrollWheelEventScrollPhase, value: 0)
                    ev?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 1)
                   // self.deltaY = self.prevDeltaY
                    self.currentSubphase = 23
                } else {
                    ev?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 2)
                }
                
            }
            //  print("deltaY - ", self.deltaY)
            
            if self.scheduledPixelsToScroll >= Int(abs(self.deltaY)) {
                self.scheduledPixelsToScroll -= Int(abs(self.deltaY))
            }
            
            if !(self.framesLeft == 2 && abs(self.deltaY) > 1) {
                
                if self.deltaY == 0 && self.framesLeft > 1 { //TODO ad-hoc
                    self.deltaY = 1
                }
                self.framesLeft -= 1
            }
       
            
            //
            ev?.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: Double(self.deltaY) * 0.1)
            //  ev?.setDoubleValueField(.scrollWheelEventDeltaAxis1, value: Double(self.direction) * Double(self.deltaY / 10))
            ev?.setIntegerValueField(self.isShiftPressed
                ? .scrollWheelEventPointDeltaAxis2
                : .scrollWheelEventPointDeltaAxis1, value: Int64(self.deltaY))
            
            // scroll in launchpad
            //  ev?.setIntegerValueField(.scrollWheelEventFixedPtDeltaAxis1, value: Int64(self.deltaY))
            
            
            
            self.postEvent(event: ev!, delay: 0)
    
            ev = nil
        }
    }
    
    func mouseEventHandler(event: NSEvent?) {
        
        if (event?.type == .mouseMoved) {
            self.currentLocation = event?.cgEvent?.location
            return
        }
        self.isShiftPressed = (event?.modifierFlags.contains(.shift))!
        print(event!)
        //   print(self.scheduledPixelsToScroll)
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        self.displayLink = DisplayLink(onQueue: DispatchQueue.main)
        displayLink?.callback = sendEvent
        displayLink?.start()

        NotificationCenter.default.addObserver(self, selector: #selector(onSystemScrollEvent(notification:)), name: NSNotification.Name(rawValue: "systemScrollEventNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onMagicScrollEvent(notification:)), name: NSNotification.Name(rawValue: "magicScrollEventNotification"), object: nil)
        
        self.maxFrames = Int(self.scrollDuration / 16)
        eventMonitor = EventMonitor(mask: [.scrollWheel, .mouseMoved],  handler: mouseEventHandler)
        eventMonitor?.start()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        displayLink?.cancel()
    }
    
    
}

