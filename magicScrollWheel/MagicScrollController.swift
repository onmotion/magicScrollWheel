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
        return _isRunning
    }
    private var isSyncNeeded = false
    
    private var magicScrollSerialQueue = DispatchQueue(label: "magicScrollSerialQueue", qos: .userInteractive)
    private var currentLocationAccessQueue = DispatchQueue(label: "currentLocationAccessQueue", attributes: .concurrent)
    
    var eventMonitor: EventMonitor?
    var displayLink: DisplayLink?
    var tf: CubicBezier
    private var _scrollEvent: CGEvent! = CGEvent(source: nil)
    
    private var _framesLeft = 0
    private var extraFrameRepeatCounter = 0

    private var peakStepFrame = 1
    private var count: Int64 = 0
    private var stepBuffer: Float = 0.0
    
    private func calcStepDelta(t: Float, prevT: Float) -> Int {
        let curEasingT = Float(tf.easing(Double(t)))
      //  print("curEasingT - ", curEasingT)
        let prevEasingT = Float(tf.easing(Double(prevT)))
     //   print("prevEasingT - ", prevEasingT)

        let easedScrolledPixelsByPrevFrame = prevEasingT * Float(maxScheduledPixelsToScroll)
        let easedScrolledPixelsByCurrentFrame = curEasingT * Float(maxScheduledPixelsToScroll)
//        print("easedScrolledPixelsByPrevFrame", easedScrolledPixelsByPrevFrame)
//        print("easedScrolledPixelsByCurrentFrame", easedScrolledPixelsByCurrentFrame)
        let floatStep = (easedScrolledPixelsByCurrentFrame - easedScrolledPixelsByPrevFrame) + stepBuffer
        let intStep = Int(floatStep)
        
        if Float(intStep) != floatStep {
            stepBuffer = floatStep - Float(intStep)
        } else {
            stepBuffer = 0
        }
        assert(intStep >= 0)
        return intStep
    }
    
    private var stepSize: Int {
        get {
            var step = 0
            
            print("- maxScheduledPixelsToScroll", self.maxScheduledPixelsToScroll)
            print("-- scheduledPixelsToScroll", self.scheduledPixelsToScroll)
            guard maxScheduledPixelsToScroll > 0 else {
                return 0
            }
            
            if isSyncNeeded{
                maxScheduledPixelsToScroll = scheduledPixelsToScroll
                isSyncNeeded = false
          
                var syncedStep = 0
                var scrolledPixelsBuffer = 0
        
                var maxSyncStep = SyncStep(step: 0, frame: 1, scrolledPixelsBuffer: 0)
                
                var syncMaxFrame = Int(Float(maxFrames) * 0.80) // 80%
                if syncMaxFrame < framesLeft {
                    syncMaxFrame = framesLeft - 1
                }
                print("syncMaxFrame", syncMaxFrame)
                
                for frame in 1...(maxFrames - syncMaxFrame) {
                    let syncedT = 1.0 - (Float(maxFrames - frame) / Float(maxFrames))
                    let prevSyncedT = 1.0 - (Float(maxFrames - (frame - 1)) / Float(maxFrames))
                    syncedStep = calcStepDelta(t: syncedT, prevT: prevSyncedT)
                    print("calc syncedStep", syncedStep)
                    scrolledPixelsBuffer += syncedStep
                    
                    if maxSyncStep.step < syncedStep { // first max
                        maxSyncStep.step = syncedStep
                        maxSyncStep.frame = frame
                        maxSyncStep.scrolledPixelsBuffer = scrolledPixelsBuffer
                    }
                    
                    if frame > 1 && maxSyncStep.step >= abs(prevStep) {
                        print("maxSyncStep.step \(maxSyncStep.step) > abs(prevStep) \(abs(prevStep))")
                        break
                    }
                }
                
//                if syncedStep < abs(prevStep) {
//                    // убрать лаг
//                    print("syncedStep \(syncedStep) < abs(prevStep) \(abs(prevStep)) need sync!")
//                 //   isSyncNeeded = true
//                    syncedStep = abs(prevStep)
//                }
                
                scheduledPixelsToScroll = maxScheduledPixelsToScroll - maxSyncStep.scrolledPixelsBuffer + maxSyncStep.step
                print("scheduledPixelsToScroll", scheduledPixelsToScroll)
                print("maxScheduledPixelsToScroll", maxScheduledPixelsToScroll)
                step = maxSyncStep.step
                print("syncedStep", maxSyncStep.step)
                self.framesLeft = maxFrames - maxSyncStep.frame + 1
                
                print("maxFrames ",maxFrames)
                print("closestFrame ", maxSyncStep.frame)
                
            } else {
                print("maxFrames", maxFrames)
                let t = 1.0 - (Float(framesLeft - 1) / Float(maxFrames))
                print("current real t", t)
                let prevRealT = 1.0 - (Float(framesLeft) / Float(maxFrames))
                print("prev real t", prevRealT)
                step = calcStepDelta(t: t, prevT: prevRealT)
                
            }
            print("framesLeft ", framesLeft)
            print("step - ", step)
            prevStep = step
            return step
        }
    }
    private var amplifier: Float = 1.0
    
    private var _scheduledPixelsToScroll: Int = 0
    
    private var maxFrames = 0
    private var prevStep = 0
    private var prevDeltaY = 0
    private var _scrolledPixelsBuffer = 0
    
    private var _maxScheduledPixelsToScroll = 0
    private var lastScrollWheelTime = CFAbsoluteTimeGetCurrent()
    
    // Settings
    let settings = Settings.shared
    
    var pixelsToScrollTextField = 40
    var pixelsToScrollLimitTextField = 30000
    var maxAmplifierLevel = 3.0
//    var bezierControlPoint1 = CGPoint.init(x: 0.34, y: 0.42)
//    var bezierControlPoint2 = CGPoint.init(x: 0.25, y: 1)
    

    
var bezierControlPoint1 = CGPoint.init(x: 0.3, y: 0.4)
var bezierControlPoint2 = CGPoint.init(x: 0.37, y: 1)
//        var bezierControlPoint1 = CGPoint.init(x: 0.44, y: 0.32)
//        var bezierControlPoint2 = CGPoint.init(x: 0.41, y: 0.95)
    
    
    
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
        // self.tf = TimingFunction(controlPoint1: bezierControlPoint1, controlPoint2: self.bezierControlPoint2, duration: 1.0)
        self.tf = CubicBezier.init(controlPoints: (x1: Double(bezierControlPoint1.x), y1: Double(bezierControlPoint1.y), x2: Double(bezierControlPoint2.x), y2: Double(bezierControlPoint2.y)))
        
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
                //                                ev?.setIntegerValueField(.scrollWheelEventScrollPhase, value: 0)
                //                    ev?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 3)
                //                   ev?.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: 0)
                //                  self.postEvent(event: ev!)
                
                ev?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 0)
                ev?.setIntegerValueField(.scrollWheelEventScrollPhase, value: 1)
                
                self.currentSubphase = .inProgress
            } else {
                ev?.setIntegerValueField(.scrollWheelEventScrollPhase, value: 2)
                ev?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 0)
            }
        } else {
            if self.currentSubphase == .start {
                
                            ev?.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: 0)
                            ev?.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: 0.0)
                ev?.setIntegerValueField(.scrollWheelEventScrollPhase, value: 4)
                ev?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 0)
                ev?.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: 0)
                self.postEvent(event: ev!)
                //                scrolledPixelsBuffer += self.absDeltaY
                //                self.deltaY = 0 // убирает лаг
                //                self.framesLeft += 1 // extra frame
                
                ev?.setIntegerValueField(.scrollWheelEventScrollPhase, value: 0)
                ev?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 1)
        
                
                self.currentSubphase = .inProgress
            } else if self.currentSubphase == .inProgress {
                ev?.setIntegerValueField(.scrollWheelEventScrollPhase, value: 0)
                 ev?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 2)
                
                self.currentSubphase = .end
            } else {
                ev?.setIntegerValueField(.scrollWheelEventScrollPhase, value: 0)
                  ev?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 2)
          
                if framesLeft == 2 {
                    self.deltaY = 0
                }
                if framesLeft == 1 {
                       ev?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 3) // momentumPhase=Ended
                    self.deltaY = 0
                }
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
        
        if self.framesLeft <= Int(Float(self.maxFrames) * 0.46) { // deceleration
            self.currentPhase = .deceleration
        }
        
        //   ev.setIntegerValueField(.eventSourceUserData, value: 1)
        ev.type = .scrollWheel
        ev.setDoubleValueField(.scrollWheelEventIsContinuous, value: 1)
    
        ev.setIntegerValueField(.scrollWheelEventScrollCount, value: self.count)
        
        if settings.useBounceEffect {
            self.addSystemDumping(ev: ev)
            if self.currentSubphase == .end && framesLeft > 2 && absDeltaY == 0 {
                //   self.deltaY = 1
            }
        }
        
        
        // smpoth end ...4321
        let absPrevDeltaY = abs(prevDeltaY)
        
        // prevent possible lag in the end
        if framesLeft == 1 && absPrevDeltaY == 0 {
            self.deltaY = 0
        }
        
        self.framesLeft -= 1
        
        if self.isShiftPressed { // horizontal scroll
                 
            ev.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: Int64(self.deltaY))
            ev.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: 0)
            ev.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: 0)
            ev.setIntegerValueField(.scrollWheelEventFixedPtDeltaAxis1, value: 0)
        } else { // vertical scroll
//            ev.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: 0)
//            ev.setFloatValueField(.scrollWheelEventFixedPtDeltaAxis1, value: 0.0)
            
            ev.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: Int64(self.deltaY))
            ev.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: 0)
            ev.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: 0)
            ev.setIntegerValueField(.scrollWheelEventFixedPtDeltaAxis2, value: 0)
            
            
        }
        
        if self.scheduledPixelsToScroll >= Int(self.absDeltaY) {
            self.scheduledPixelsToScroll -= Int(self.absDeltaY) // TODO refactor
        }
        
        self.prevDeltaY = deltaY
        print("deltaY", deltaY)
        self.postEvent(event: ev, delay: 0)
        
    }
    
    /// Raised when real scroll has occurred - Concurrent Event queue
    ///
    /// - Parameter event:
    @objc func systemScrollEventHandler(event: CGEvent)
    {
        print("🌴onSystemScrollEvent🌴🌴🌴🌴🌴🌴🌴🌴🌴🌴🌴🌴🌴🌴🌴🌴🌴\n_____________________________________________\n")
       // scrolledPixelsBuffer = 0
        
        self.scrollEvent = event
        
        let scrollWheelEventDeltaAxis1 =  abs(Float(event.getIntegerValueField(.scrollWheelEventDeltaAxis1))) * settings.accelerationMultiplier * 3
        self.amplifier = log2(scrollWheelEventDeltaAxis1)
        if self.amplifier < 1 {
            self.amplifier = 1
        }
     
        print("let scrollWheelEventDeltaAxis1 amplifier", scrollWheelEventDeltaAxis1)
        print("self.amplifier", self.amplifier)
        
        var deltaAxis: Int64 = 0
        if isShiftPressed {
            deltaAxis = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
            if deltaAxis == 0 {
                deltaAxis = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
            }
        } else {
            deltaAxis = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        }
        self.direction = deltaAxis > 0 ? 1 : -1
        
        self.scheduledPixelsToScroll += Int(Float(self.pixelsToScrollTextField) * self.amplifier)
     //   self.maxScheduledPixelsToScroll = self.scheduledPixelsToScroll
//let requestedScrollPixels = Int(Float(self.pixelsToScrollTextField) * self.amplifier)
//        if requestedScrollPixels < self.maxScheduledPixelsToScroll && scheduledPixelsToScroll <  self.maxScheduledPixelsToScroll {
//            self.maxScheduledPixelsToScroll += requestedScrollPixels
//        } else {
//            self.maxScheduledPixelsToScroll = Int(Float(self.pixelsToScrollTextField) * self.amplifier)
//        }
        
        
        
        
        if self.framesLeft == 0 {
            self.displayLink?.start()
            self.framesLeft = self.maxFrames
            scrolledPixelsBuffer = 0
        } else {
            isSyncNeeded = true
            
           // self.count += 1
        }
        
        if self.currentPhase == .deceleration {
            self.currentSubphase = .start
            self.currentPhase = .acceleration
        }
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
    
    private func calcMaxFrames() {
        self.maxFrames = Int(settings.scrollDuration / 16)
    }
    
    @objc private func onScrollDurationChanged() {
        self.calcMaxFrames()
    }
    
    public func run() {
        print("run MagicScrollController")
        self._isRunning = true
        //    self.displayLink = DisplayLink(onQueue: magicScrollSerialQueue)
        self.displayLink = DisplayLink(onQueue: DispatchQueue.main)
        displayLink?.callback = sendEvent
        
        NotificationCenter.default.addObserver(self, selector: #selector(onScrollDurationChanged), name: NSNotification.Name(rawValue: "scrollDurationChanged"), object: nil)
        
        self.calcMaxFrames()
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
                self.count = 0
                prevDeltaY = 0
                prevStep = 0
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
            self._scheduledPixelsToScroll = newValue < pixelsToScrollLimitTextField ? newValue : pixelsToScrollLimitTextField
            
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
            return val
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
    
    private var currentFrame: Int {
        get {
            return maxFrames - framesLeft
        }
    }
    
}

