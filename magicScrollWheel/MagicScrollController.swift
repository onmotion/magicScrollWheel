//
//  ViewController.swift
//  magicScrollWheel
//
//  Created by Aleksandr Kozhevnikov on 31/03/2019.
//  Copyright © 2019 Aleksandr Kozhevnikov. All rights reserved.
//

import Cocoa

public class MagicScrollController {
    
    static let shared: MagicScrollController = MagicScrollController()
    private var _isRunning = false
    var isRunning: Bool {
        get {
            return _isRunning
        }
    }
    
    private var magicScrollSerialQueue = DispatchQueue(label: "magicScrollSerialQueue", qos: .userInteractive)
    
    var eventMonitor: EventMonitor?
    var displayLink: DisplayLink?
    var tf: TimingFunction
    private var scrollEvent: CGEvent! = CGEvent(source: nil)
    
    private var framesLeft = 0 {
        didSet {
            if framesLeft == 0 {
     
                self.displayLink?.cancel()
          
                self.currentPhase = .acceleration
                self.currentSubphase = .start
                scrolledPixelsBuffer = 0
            }
        }
    }
    
    private var stepSize: Int {
        get {
            let t = 1.0 - (Double(framesLeft) / Double(maxFrames))
            var step = 0
            let curEasingT = Double(tf.progress(at: CGFloat(t)))
            print("curEasingT - ", curEasingT)
            step = Int(Double(maxScheduledPixelsToScroll) * curEasingT) - scrolledPixelsBuffer
            print("scrolledPixelsBuffer - ", scrolledPixelsBuffer)
            if step < 0 {
                step = 0
            }
            if isSyncNeeded && framesLeft > 0 {
                isSyncNeeded = false
                var closestFrame = 1;
                var syncedEasingT = 0.0
                var syncedStep = 0
                var syncedScrolledPixelsBuffer = 0
                var prevSyncedStep = 0
                for frame in 1...maxFrames {
                    let syncedT = 1.0 - (Double(maxFrames - frame) / Double(maxFrames))
                    syncedEasingT = Double(tf.progress(at: CGFloat(syncedT)))
                    syncedStep = Int(Double(maxScheduledPixelsToScroll) * syncedEasingT) - syncedScrolledPixelsBuffer
                    print(syncedStep, syncedEasingT)
                    syncedScrolledPixelsBuffer += syncedStep
                    closestFrame = frame
                    if syncedStep > prevStep{
                        break
                    } else if syncedStep < prevSyncedStep {
                        syncedStep = prevSyncedStep
                        break
                    }
                    
                    // то что было на предыдущем шаге
                    //  closestSyncedEasingT = syncedEasingT
                    prevSyncedStep = syncedStep
                }
                step = syncedStep
                print("syncedStep", syncedStep)
                self.framesLeft = maxFrames - closestFrame
                //  scrolledPixelsBuffer = Int(Double(maxScheduledPixelsToScroll) * syncedEasingT)
                scrolledPixelsBuffer = syncedScrolledPixelsBuffer
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
    
    private var amplifier: Double {
        get {
            guard self.currentPhase == .acceleration else { return 1 }
            let currentTime = (UInt64(DispatchTime.now().uptimeNanoseconds) - self.lastScrollWheelTime) / 1_000_000
            if currentTime < self.amplifierSensitivityLevel {
                let amplifierCoef = round(log10(Double(self.amplifierSensitivityLevel) / Double(currentTime > 0 ? currentTime : 1)) * 100) / 100
                let _amplifier = (1 + (amplifierMultiplier * amplifierCoef))
                guard _amplifier < self.maxAmplifierLevel else { return 1 }
                return _amplifier
            } else {
                return 1
            }
        }
    }
    
    private var scheduledPixelsToScroll: Int = 0{
        didSet {
            if (scheduledPixelsToScroll > oldValue) {
                self.maxScheduledPixelsToScroll = scheduledPixelsToScroll
            }
        }
    }
    
    private var maxFrames = 0
    private var prevStep = 0
    private var scrolledPixelsBuffer = 0
    private var maxScheduledPixelsToScroll = 0
    private var lastScrollWheelTime: UInt64 = DispatchTime.now().uptimeNanoseconds
    
    // Settings
    var scrollDuration = 400 //ms
    var useSystemDamping = true;
    var pixelsToScrollTextField = 60
    var amplifierSensitivityLevel = 80 // ms
    var amplifierMultiplier = 3.0
    var maxAmplifierLevel = 10.0
    //    var bezierControlPoint1 = CGPoint.init(x: 0.4, y: 0.8)
    //    var bezierControlPoint2 = CGPoint.init(x: 0.5, y: 1)
    var bezierControlPoint1 = CGPoint.init(x: 0.2, y: 0.5)
    var bezierControlPoint2 = CGPoint.init(x: 0.3, y: 0.9)
    
    
    private var absDeltaY: Int = 0
    private var deltaY: Int {
        get {
            return self.absDeltaY * self.direction
        }
        set(val) {
            self.absDeltaY = abs(val)
        }
    }
    
    private var currentLocation: CGPoint?
    private var isShiftPressed = false;
    private var direction = 1 {
        willSet{
            if newValue != direction {
                self.currentPhase = .acceleration
                self.currentSubphase = .start
                self.scheduledPixelsToScroll = 0
            }
        }
    }
    
    private var isSyncNeeded = false
    private var currentPhase: Phase = .acceleration
    private var currentSubphase: Subphase = .start
    
    
    init() {
        print("init MagicScrollController")
        self.tf = TimingFunction(controlPoint1: bezierControlPoint1, controlPoint2: self.bezierControlPoint2, duration: 1.0)
    }
    
    private func postEvent(event: CGEvent, delay: UInt32 = 0) {
        guard let location = self.currentLocation else {
            print("current mouse location is not defined...")
            return
        }
        event.location = location
        event.post(tap: .cgSessionEventTap)
    }
    
    
    
    
    /// Adds a bump effect, like using a trackpad or magic mouse.
    ///
    /// - Parameter ev: CGEvent?
    func addSystemDumping(ev: CGEvent?) {
        if self.currentPhase == .acceleration {
            if self.currentSubphase == .start {
                //                ev?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 3)
                //                ev?.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: 0)
                //                self.postEvent(event: ev!)
                ev?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 0)
                ev?.setIntegerValueField(.scrollWheelEventScrollPhase, value: 1)
                
                self.currentSubphase = .inProgress
            } else {
                ev?.setIntegerValueField(.scrollWheelEventScrollPhase, value: 2)
            }
        } else {
            if self.currentSubphase == .inProgress {
                ev?.setIntegerValueField(.scrollWheelEventScrollPhase, value: 4)
                ev?.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: 0) // убирает лаг
                self.postEvent(event: ev!)
                
                ev?.setIntegerValueField(.scrollWheelEventScrollPhase, value: 0)
                ev?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 1)
                
                self.currentSubphase = .end
            } else {
                ev?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 2)
            }
        }
    }
    
    @objc func sendEvent() {
        
        guard let ev = self.scrollEvent else { return }
        //  let ev = CGEvent.init(source: nil)!
        
        guard self.framesLeft > 0 else {
            self.scheduledPixelsToScroll = 0
            return
        }
        self.deltaY = self.stepSize
        
        if self.framesLeft <= self.maxFrames - Int(Double(self.maxFrames) / 2) { // deceleration
            self.currentPhase = .deceleration
        }
        
        if self.useSystemDamping {
            self.addSystemDumping(ev: ev)
        }
        
        //  ev?.setIntegerValueField(.eventSourceUserData, value: 1)
        ev.type = .scrollWheel
        ev.setDoubleValueField(.scrollWheelEventIsContinuous, value: 1)
        if self.isShiftPressed {
            ev.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: Int64(self.deltaY))
            ev.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: 0)
            //     ev.setIntegerValueField(.scrollWheelEventFixedPtDeltaAxis2, value: Int64(self.direction))
        } else {
            // vertical scroll
            ev.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: Int64(self.deltaY))
            //   ev.setIntegerValueField(.scrollWheelEventFixedPtDeltaAxis1, value: Int64(self.direction))
        }
        
        
        self.framesLeft -= 1
        
        if self.scheduledPixelsToScroll >= Int(self.absDeltaY) {
            self.scheduledPixelsToScroll -= Int(self.absDeltaY)
        }
        
        self.postEvent(event: ev, delay: 0)
        
    }
    
    /// Raised when real scroll has occurred
    ///
    /// - Parameter event:
    @objc func systemScrollEventHandler(event: CGEvent)
    {
        print("🌴onSystemScrollEvent🌴🌴🌴🌴🌴🌴🌴🌴🌴🌴🌴🌴🌴🌴🌴🌴🌴")
        print("_____________________________________________\n")
        print(event)
        scrolledPixelsBuffer = 0
        
        self.scrollEvent = event
        self.direction = self.scrollEvent.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) < 0 ? -1 : 1
        self.scheduledPixelsToScroll += Int(Double(self.pixelsToScrollTextField) * self.amplifier)
        self.isSyncNeeded = true
        
        if self.framesLeft == 0 {
            self.displayLink?.start()
            self.framesLeft = self.maxFrames
        }
        
        if self.currentPhase == .deceleration {
            self.currentSubphase = .start
            self.currentPhase = .acceleration
        }
        
        self.lastScrollWheelTime = DispatchTime.now().uptimeNanoseconds
        
    }
    
    /// Raised on mouse event with mask: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .flagsChanged]
    ///
    /// - Parameter event: mouse NSEvent?
    func mouseEventHandler(event: CGEvent) {
        self.currentLocation = event.location
        if event.type == .flagsChanged {
            isShiftPressed = event.flags.contains(.maskShift)
        }
    }
    
    public func run() {
        print("run MagicScrollController")
        self._isRunning = true
           self.displayLink = DisplayLink(onQueue: magicScrollSerialQueue)
       // self.displayLink = DisplayLink(onQueue: DispatchQueue.main)
        displayLink?.callback = sendEvent
        
        /// Raised when a real scroll has occurred
        //        NotificationCenter.default.addObserver(self, selector: #selector(onSystemScrollEvent(notification:)), name: NSNotification.Name(rawValue: "systemScrollEventNotification"), object: nil)
        
        //        NotificationCenter.default.addObserver(self, selector: #selector(onMouseMovedEventNotification(notification:)), name: NSNotification.Name(rawValue: "mouseMovedEventNotification"), object: nil)
        
        self.maxFrames = Int(self.scrollDuration / 16)
        eventMonitor = EventMonitor()
        eventMonitor?.start()
    }
    
    public func stop() {
        print("stop MagicScrollController")
        self._isRunning = false
        displayLink?.cancel()
        eventMonitor?.stop()
        eventMonitor = nil
        displayLink = nil
        NotificationCenter.default.removeObserver(self)
    }
    
    deinit {
        print("deinit MagicScrollController")
        self.stop()
    }
    
    
    
}

