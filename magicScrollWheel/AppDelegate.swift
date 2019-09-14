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

struct ScrollUnit {
    var step: Int?
    var easingT: Double?
    var framesLeft: Int?
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var accessQueue = DispatchQueue(label: "accessQueue", qos: .userInteractive)
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    var eventMonitor: EventMonitor?

    var scrollDuration = 360 //ms
    var currentTimePoint = 0.0 // 0-1
    var lastTime: UInt64 = DispatchTime.now().uptimeNanoseconds
    var startTime: UInt64 = 0
    
    var framesLeft = 0 {
        didSet {
            if framesLeft == 0 {
                self.currentPhase = 1
                self.currentSubphase = 11
                scrolledPixelsBuffer = 0
            }
        }
    }
    var scrollDict = [0.0: ScrollUnit()]
    var maxFrames = 0
    var useSystemDamping = false;
    var damperLevel = 30 //1 - 100
    var amplifierSensitivityLevel = 80 // ms
    var log10Remainder = 0.0
    var prevEasingT = 0.0
    var prevT = 0.0
    var prevStep = 0
    
    var displayLink: DisplayLink? = nil
    var scrolledPixelsBuffer = 0
    
    let transitioningLayer = CALayer()
    let bezierControlPoint1 = CGPoint.init(x: 0.3, y: 0.9)
    let bezierControlPoint2 = CGPoint.init(x: 0.6, y: 1)
    let tf: TimingFunction
    var stepSize: Int {
        get {
            let t = 1.0 - (Double(framesLeft) / Double(maxFrames))
            var step = 0
            let curEasingT = Double(tf.progress(at: CGFloat(t)))
            print("curEasingT - ", curEasingT)
            step = Int(Double(maxScheduledPixelsToScroll) * curEasingT) - scrolledPixelsBuffer
            print("maxScheduledPixelsToScroll \(maxScheduledPixelsToScroll)")
            print("scrolledPixelsBuffer - ", scrolledPixelsBuffer)
            if step < 0 {
               //
            }
            if isSyncNeeded {
                isSyncNeeded = false
                var closestFrame = 1;
                var syncedEasingT = 0.0
              //  var closestSyncedEasingT = 0.0
                var syncedStep = 0
                for frame in 1...maxFrames {
                    let syncedT = 1.0 - (Double(maxFrames - frame) / Double(maxFrames))
                    syncedEasingT = Double(tf.progress(at: CGFloat(syncedT)))
                    syncedStep = Int(Double(maxScheduledPixelsToScroll) * syncedEasingT) - scrolledPixelsBuffer
                    closestFrame = frame
                    if syncedStep > prevStep {
                        break
                    }
                    
                    // то что было на предыдущем шаге
                  //  closestSyncedEasingT = syncedEasingT
                    
                }
                step = (prevStep + syncedStep) / 2
                self.framesLeft = maxFrames - closestFrame
                scrolledPixelsBuffer = Int(Double(maxScheduledPixelsToScroll) * syncedEasingT)
                print("closestFrame ",closestFrame)
                print("syncedEasingT ",syncedEasingT)
                print("maxScheduledPixelsToScroll", maxScheduledPixelsToScroll)
            } else {
                scrolledPixelsBuffer += step
            }
            print("framesLeft ", framesLeft)
            
            
            print("step - ", step)
            prevStep = step
            return step
        }
    }
    var pixelsToScrollTextField = 60
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
    var maxAmplifierLevel = 4.0
    var amplifierStep = 1.0
    var damperFramesLeft = 0
    
    var scheduledPixelsToScroll: Int = 0{
        didSet {
            if (scheduledPixelsToScroll > oldValue) {
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
    var isSyncNeeded = false
    
    var currentPhase: Int64 = 0
    var currentSubphase: Int64 = 11
    
    var scrollEvent: CGEvent! = CGEvent(source: nil)
    
    func postEvent(event: CGEvent, delay: UInt32 = 0) {
        guard let location = self.currentLocation else {
            return
        }
            event.location = location
            event.post(tap: .cghidEventTap)
    }
    
    @objc func onSystemScrollEvent(notification:Notification)
    {
        print("🌴onSystemScrollEvent🌴🌴🌴🌴🌴🌴🌴🌴🌴🌴🌴🌴🌴🌴🌴🌴🌴")
        scrolledPixelsBuffer = 0
        
        self.lastTime = DispatchTime.now().uptimeNanoseconds
        //        return
        
        self.scrollEvent = notification.userInfo!["event"] as! CGEvent
        
        self.direction = self.scrollEvent.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) < 0 ? -1 : 1
        
        self.scheduledPixelsToScroll += Int(Double(self.pixelsToScrollTextField) * self.amplifier)
      
//        if startTime == 0 { // начало работы magicScroll
//            startTime = DispatchTime.now().uptimeNanoseconds
//        }
        
        if self.framesLeft > 0 {
            isSyncNeeded = true //TODO вынести
        }
        self.lastScrollWheelTime = DispatchTime.now().uptimeNanoseconds
        if self.currentPhase == 1{
            if self.framesLeft ==  0 {
                scrolledPixelsBuffer = 0
                scrollDict.removeAll()
                self.framesLeft = self.maxFrames
            } else {
               // self.framesLeft = self.maxFrames
//                self.framesLeft = Int(Double(self.maxFrames) - Double(self.maxFrames) * Double(self.bezierControlPoint1.x))
//                scrolledPixelsBuffer = Int(Double(tf.progress(at: self.bezierControlPoint1.x)) * Double(maxScheduledPixelsToScroll))
            }

            if (UInt64(DispatchTime.now().uptimeNanoseconds) - lastScrollWheelTime) / 1_000_000 < self.amplifierSensitivityLevel {
                if self.amplifier < self.maxAmplifierLevel {
                    self.amplifier += 0.5
                   //  self.amplifier += round(log2(self.amplifier + self.amplifierStep) * 10) / 10
                }
            }
            
        } else if self.currentPhase == 2{
          
           // self.framesLeft = Int(Double(self.maxFrames) / 1.2)
            self.currentPhase = 1
            self.currentSubphase = 11
        } else {
                self.currentSubphase = 11
            self.currentPhase = 1
        }
        
        //     sendEvent(ev: notification.userInfo!["event"] as! CGEvent)
    }
    
    @objc func onMagicScrollEvent(notification:Notification) {
        self.lastTime = DispatchTime.now().uptimeNanoseconds
        //       sendEvent(ev: notification.userInfo!["event"] as! CGEvent)
        self.scrollEvent = notification.userInfo!["event"] as! CGEvent
    }
    
    @objc func sendEvent() {
        accessQueue.async {
            //   let ev = self.scrollEvent
      
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

                 if self.framesLeft <= self.maxFrames - Int(Double(self.maxFrames) * 0.5) { // deceleration
                    self.currentPhase = 2
                } else {
                    // acceleration
                    if absPrevDeltaY - abs(self.deltaY) > 1 { // иногда может замедляться на 1
                //  TODO for remove lag
                      //  self.deltaY = self.prevDeltaY
                       // self.deltaY = abs(self.deltaY) + Int((absPrevDeltaY - abs(self.deltaY)) / 2)
                    } else {
                        if abs(self.deltaY) <= 0 {
                         //   self.deltaY = 0
                        } else {
                          //  self.deltaY = abs(self.deltaY) + Int(round(log10(Double(abs(self.deltaY))).rounded()) * self.amplifier)
                        }
                    }
                }
                
                
            }
            
            var ev = CGEvent.init(source: nil)
            ev?.type = .scrollWheel
            ev?.setDoubleValueField(.scrollWheelEventIsContinuous, value: 1)
            
            // ev?.setIntegerValueField(.scrollWheelEventScrollCount, value: 2000)
            //    ev?.setIntegerValueField(.eventSourceUserData, value: 1)
            
                        print("self.currentPhase = ", self.currentPhase)
                        print("self.currentSubphase = ", self.currentSubphase)
            
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
            
                    
//                    ev?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 3)
//                    ev?.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: 0)
//                    self.postEvent(event: ev!)
                    ev?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 0)
                    ev?.setIntegerValueField(.scrollWheelEventScrollPhase, value: 1)
                 
                    self.currentSubphase = 12
                } else if self.currentSubphase == 12 {
                    ev?.setIntegerValueField(.scrollWheelEventScrollPhase, value: 2)
                } else {
                    self.currentSubphase = 12
                }
            } else {
                if self.currentSubphase == 12 {
                    ev?.setIntegerValueField(.scrollWheelEventScrollPhase, value: 4)
                    ev?.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: 0) // убирает лаг
                   // self.deltaY = 0
                    self.postEvent(event: ev!)
                    ev?.setIntegerValueField(.scrollWheelEventScrollPhase, value: 0)
                    ev?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 1)
                 //   self.deltaY = self.prevDeltaY
                    self.currentSubphase = 23
                } else {
                    ev?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 2)
                }
                
            }
            
            if self.scheduledPixelsToScroll >= Int(abs(self.deltaY)) {
                self.scheduledPixelsToScroll -= Int(abs(self.deltaY))
            }
            
//            if !(self.framesLeft == 2 && abs(self.deltaY) > 1) {
//
////                if self.deltaY == 0 && self.framesLeft > 1 { //TODO ad-hoc
////                    self.deltaY = 1
////                }
//                self.framesLeft -= 1
//            }
            
            self.framesLeft -= 1
       
    
            self.prevDeltaY = self.deltaY
            
            //
            ev?.setIntegerValueField(.scrollWheelEventFixedPtDeltaAxis1, value: Int64(self.deltaY))
         //   ev?.setIntegerValueField(.eventSourceUserData, value: 1)
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
        print("_____________________________________________\n")
        print(event!)
        //   print(self.scheduledPixelsToScroll)
    }
    
    override init() {
        self.tf = TimingFunction(controlPoint1: bezierControlPoint1, controlPoint2: self.bezierControlPoint2, duration: 1.0)
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

