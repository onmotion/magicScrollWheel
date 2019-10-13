//
//  ViewController.swift
//  magicScrollWheel
//
//  Created by Aleksandr Kozhevnikov on 31/03/2019.
//  Copyright © 2019 Aleksandr Kozhevnikov. All rights reserved.
//

import Cocoa



extension MagicScrollController {
    
    
    private var framesLeft: Int {
        get {
            
            return _framesLeft
        }
        set {
            
            self._framesLeft = newValue
            
            if newValue == 0 {
                self.displayLink?.cancel()
                self.currentPhase = .acceleration
                self.currentSubphase = .start
                self.scrolledPixelsBuffer = 0
                scheduledPixelsToScroll = 0
            }
        }
    }
    
    
    private var scrolledPixelsBuffer: Int {
        get {
            return _scrolledPixelsBuffer
        }
        set {
            
            self._scrolledPixelsBuffer = newValue
            
        }
    }
    
//    private var isSyncNeeded: Bool {
//        return scrolledPixelsBuffer == 0 && framesLeft < maxFrames
//    }
    
    
    private var scrollEvent: CGEvent {
        get {
            return _scrollEvent
        }
        set {
            
            self._scrollEvent = newValue
            
        }
    }
    
    private var maxScheduledPixelsToScroll: Int {
        get {
            return _maxScheduledPixelsToScroll
        }
        set {
            
            self._maxScheduledPixelsToScroll = newValue
            
        }
    }
    
    private var scheduledPixelsToScroll: Int {
        get {
            return _scheduledPixelsToScroll
        }
        set {
            
         //   let oldValue = self._scheduledPixelsToScroll
            if newValue < pixelsToScrollLimitTextField {
                self._scheduledPixelsToScroll = newValue
            }
            
            print("- scheduledPixelsToScroll", self._scheduledPixelsToScroll)
            if (self._scheduledPixelsToScroll > self.maxScheduledPixelsToScroll) {
                self.maxScheduledPixelsToScroll = self._scheduledPixelsToScroll
            } else if self._scheduledPixelsToScroll == 0 {
                self.maxScheduledPixelsToScroll = 0
            }
            
        }
    }
    
    private var currentLocation: CGPoint? {
        get {
            var val: CGPoint? = nil
            currentLocationAccessQueue.sync {
                val = _currentLocation
            }
            return val!
        }
        set {
            currentLocationAccessQueue.async(flags: .barrier) {
                self._currentLocation = newValue
            }
        }
    }
    
    private var deltaY: Int {
        get {
            
            return self.absDeltaY * self.direction
        }
        set(val) {
            
            self.absDeltaY = abs(val)
            
        }
    }
    
    private var currentPhase: Phase {
        get {
            return _currentPhase
        }
        set {
            
            let oldValue = self._currentPhase
            if oldValue != newValue {
                self.currentSubphase = .start
            }
            self._currentPhase = newValue
            
        }
    }
    
    private var currentSubphase: Subphase {
        get {
            return _currentSubphase
        }
        set {
            self._currentSubphase = newValue
        }
    }
    
}

public class MagicScrollController {
    
    static let shared: MagicScrollController = MagicScrollController()
    private var _isRunning = false
    var isRunning: Bool {
        
        return _isRunning
        
    }
    private var isSyncNeeded = false
    
    private var magicScrollSerialQueue = DispatchQueue(label: "magicScrollSerialQueue", qos: .userInteractive)
    private var framesLeftAccessQueue = DispatchQueue(label: "framesLeftAccessQueue", attributes: .concurrent)
    //   private var scrolledPixelsBufferAccessQueue = DispatchQueue(label: "scrolledPixelsBufferAccessQueue", attributes: .concurrent)
    private var scrollEventAccessQueue = DispatchQueue(label: "scrollEventAccessQueue", attributes: .concurrent)
      private var isSyncNeededAccessQueue = DispatchQueue(label: "isSyncNeededAccessQueue", attributes: .concurrent)
    
    private var scheduledPixelsToScrollAccessQueue = DispatchQueue(label: "scheduledPixelsToScrollAccessQueue", attributes: .concurrent)
    private var currentLocationAccessQueue = DispatchQueue(label: "currentLocationAccessQueue", attributes: .concurrent)
    private var deltaYAccessQueue = DispatchQueue(label: "deltaYAccessQueue", attributes: .concurrent)
    private var phaseAccessQueue = DispatchQueue(label: "phaseAccessQueue", attributes: .concurrent)
    
    var eventMonitor: EventMonitor?
    var displayLink: DisplayLink?
    var tf: TimingFunction
    private var _scrollEvent: CGEvent! = CGEvent(source: nil)
    
    private var _framesLeft = 0
    
    private var stepSize: Int {
        get {
            var step = 0
            print("- maxScheduledPixelsToScroll", self.maxScheduledPixelsToScroll)
            if isSyncNeeded {
                 isSyncNeeded = false
                var closestFrame = 1;
                var syncedEasingT = 0.0
                var syncedStep = 0
                var peakSyncedStep = 0
                var peakSyncedClosestFrame = 1
                var peakSyncedScrolledPixelsBuffer = 0
                
                var syncedScrolledPixelsBuffer = 0
               // var prevSyncedStep = 0
                
                for frame in 1...maxFrames {
                    let syncedT = 1.0 - (Double(maxFrames - frame) / Double(maxFrames))
                    syncedEasingT = Double(tf.progress(at: CGFloat(syncedT)))
                    syncedStep = Int(Double(maxScheduledPixelsToScroll) * syncedEasingT) - syncedScrolledPixelsBuffer
                    print("syncedStep calc", syncedStep, syncedEasingT)
                    syncedScrolledPixelsBuffer += syncedStep
                    
                    if syncedStep >= prevStep{ // found step
                        closestFrame = frame
                        scrolledPixelsBuffer = syncedScrolledPixelsBuffer
                        break
                    } else if frame == maxFrames {
                        closestFrame = peakSyncedClosestFrame
                        syncedStep = peakSyncedStep
                        scrolledPixelsBuffer = peakSyncedScrolledPixelsBuffer
                        
                        break
                    }
                    
                    //                    else if syncedStep < prevSyncedStep {
                    //                        closestFrame = frame - 1
                    //                        syncedStep = prevSyncedStep
                    //                        scrolledPixelsBuffer = syncedScrolledPixelsBuffer - syncedStep
                    //                        break
                    //                    }
                    
                    // то что было на предыдущем шаге
                    //  closestSyncedEasingT = syncedEasingT
                    if syncedStep > peakSyncedStep {
                        peakSyncedClosestFrame = frame
                        peakSyncedStep = syncedStep
                        peakSyncedScrolledPixelsBuffer = syncedScrolledPixelsBuffer
                    }
                    
                  //  prevSyncedStep = syncedStep
                }
                scheduledPixelsToScroll = maxScheduledPixelsToScroll - scrolledPixelsBuffer + syncedStep
                step = syncedStep
                print("syncedStep", syncedStep)
                self.framesLeft = maxFrames - closestFrame + 1
                //  scrolledPixelsBuffer = Int(Double(maxScheduledPixelsToScroll) * syncedEasingT)
                
                print("closestFrame ",closestFrame)
                print("syncedEasingT ",syncedEasingT)
                print("scheduledPixelsToScroll", scheduledPixelsToScroll)
                print("maxScheduledPixelsToScroll", maxScheduledPixelsToScroll)
            } else {
                let t = 1.0 - (Double(framesLeft - 1) / Double(maxFrames))
                
                let curEasingT = Double(tf.progress(at: CGFloat(t)))
                print("curEasingT - ", curEasingT)
                step = Int(Double(maxScheduledPixelsToScroll) * curEasingT) - scrolledPixelsBuffer
            
                print("scrolledPixelsBuffer - ", scrolledPixelsBuffer)
                if step <= 0 {
                    step = 0 //TODO
                }
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
            let currentTime = CFAbsoluteTimeGetCurrent()
            let timeDelta = (currentTime - self.lastScrollWheelTime) * 1000
            self.lastScrollWheelTime = currentTime
            return 1
            if timeDelta < self.amplifierSensitivityLevel {
                let amplifierCoef = round((Double(self.amplifierSensitivityLevel) / timeDelta) * 100) / 100
                print("amplifierCoef \(amplifierCoef)")
                let _amplifier = amplifierCoef
               // let _amplifier = (1 + (amplifierMultiplier * amplifierCoef))
                guard _amplifier < self.maxAmplifierLevel else { return self.maxAmplifierLevel }
                print("amplifier \(_amplifier)")
                return _amplifier
            } else {
                print("amplifier \(1)")
                return 1
            }
        }
    }
    
    private var _scheduledPixelsToScroll: Int = 0
    
    private var maxFrames = 0
    private var prevStep = 0
    private var _scrolledPixelsBuffer = 0
    private var _maxScheduledPixelsToScroll = 0
    private var lastScrollWheelTime = CFAbsoluteTimeGetCurrent()
    
    // Settings
    let settings = Settings.shared
    var scrollDuration = 360 //ms
    var pixelsToScrollTextField = 60
    var pixelsToScrollLimitTextField = 1200
    var amplifierSensitivityLevel = 80.0 // ms
    var amplifierMultiplier = 3.0
    var maxAmplifierLevel = 4.0
    //        var bezierControlPoint1 = CGPoint.init(x: 0.4, y: 0.5)
    //        var bezierControlPoint2 = CGPoint.init(x: 0.5, y: 1)
    //ease
//    var bezierControlPoint1 = CGPoint.init(x: 0.25, y: 0.1)
//    var bezierControlPoint2 = CGPoint.init(x: 0.3, y: 0.98)
        var bezierControlPoint1 = CGPoint.init(x: 0.4, y: 0.4)
        var bezierControlPoint2 = CGPoint.init(x: 0.2, y: 1)
    
    
    private var absDeltaY: Int = 0
    
    
    private var _currentLocation: CGPoint?
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
    
    private var _isSyncNeeded = false
    private var _currentPhase: Phase = .acceleration
    
    private var _currentSubphase: Subphase = .start
    
    
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
        print("NSEvent phase", currentPhase, currentSubphase)
        if self.currentPhase == .acceleration {
            if self.currentSubphase == .start {
                //                ev?.setIntegerValueField(.scrollWheelEventScrollPhase, value: 0)
                //    ev?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 3)
                //   ev?.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: 0)
                //  self.postEvent(event: ev!)
                ev?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 0)
                ev?.setIntegerValueField(.scrollWheelEventScrollPhase, value: 1)
                
                self.currentSubphase = .inProgress
            } else {
                ev?.setIntegerValueField(.scrollWheelEventScrollPhase, value: 2)
                ev?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 0)
            }
        } else {
            if self.currentSubphase == .start {
                ev?.setIntegerValueField(.scrollWheelEventScrollPhase, value: 4)
                ev?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 0)
                self.deltaY = 0 // убирает лаг
                self.framesLeft += 1 // extra frame
                //   ev?.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: 0) // убирает лаг
                // self.postEvent(event: ev!)
                self.currentSubphase = .inProgress
            } else if self.currentSubphase == .inProgress {
                ev?.setIntegerValueField(.scrollWheelEventScrollPhase, value: 0)
                ev?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 1)
                
                self.currentSubphase = .end
            } else {
                ev?.setIntegerValueField(.scrollWheelEventScrollPhase, value: 0)
                ev?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 2)
            }
        }
    }
    
    @objc func sendEvent() {
        
        //  guard let ev = self.scrollEvent else { return }
        let ev = self.scrollEvent
        //  let ev = CGEvent.init(source: nil)!
        
        guard self.framesLeft > 0 else {
            self.scheduledPixelsToScroll = 0
            return
        }
        self.deltaY = self.stepSize
        
        if self.framesLeft <= self.maxFrames - Int(Double(self.maxFrames) / 1.8) { // deceleration
            self.currentPhase = .deceleration
        }
        
        
        
        //  ev?.setIntegerValueField(.eventSourceUserData, value: 1)
        ev.type = .scrollWheel
        ev.setDoubleValueField(.scrollWheelEventIsContinuous, value: 1)
        
        if settings.useSystemDamping {
            self.addSystemDumping(ev: ev)
        }
        
        if self.isShiftPressed {
            ev.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: Int64(self.deltaY))
            ev.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: 0)
            //     ev.setIntegerValueField(.scrollWheelEventFixedPtDeltaAxis2, value: Int64(self.direction))
        } else {
            // vertical scroll
            ev.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: 0)
            ev.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: Int64(self.deltaY))
            //   ev.setIntegerValueField(.scrollWheelEventFixedPtDeltaAxis1, value: Int64(self.direction))
        }
        
        
        
        self.framesLeft -= 1
        
        if self.scheduledPixelsToScroll >= Int(self.absDeltaY) {
            self.scheduledPixelsToScroll -= Int(self.absDeltaY) // TODO refactor
        }
        
        self.postEvent(event: ev, delay: 0)
        
    }
    
    /// Raised when real scroll has occurred - Concurrent Event queue
    ///
    /// - Parameter event:
    @objc func systemScrollEventHandler(event: CGEvent)
    {
        print("🌴onSystemScrollEvent🌴🌴🌴🌴🌴🌴🌴🌴🌴🌴🌴🌴🌴🌴🌴🌴🌴")
        print("_____________________________________________\n")
        print(event)
        scrolledPixelsBuffer = 0
        
        self.scrollEvent = event
        
        self.direction = self.scrollEvent.getIntegerValueField(.scrollWheelEventDeltaAxis1) < 0 ? -1 : 1
        self.scheduledPixelsToScroll += Int(Double(self.pixelsToScrollTextField) * self.amplifier)
        
        
        if self.framesLeft == 0 {
            self.displayLink?.start()
            self.framesLeft = self.maxFrames
        } else {
            isSyncNeeded = true
        }
        
        if self.currentPhase == .deceleration {
            self.currentSubphase = .start
            self.currentPhase = .acceleration
        }
        
   //     self.lastScrollWheelTime = DispatchTime.now().uptimeNanoseconds
        
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
        //    self.displayLink = DisplayLink(onQueue: magicScrollSerialQueue)
        self.displayLink = DisplayLink(onQueue: DispatchQueue.main)
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

