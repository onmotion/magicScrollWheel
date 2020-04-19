//
//  Settings.swift
//  magicScrollWheel
//
//  Created by Aleksandr Kozhevnikov on 06/10/2019.
//  Copyright © 2019 Aleksandr Kozhevnikov. All rights reserved.
//

import Foundation

class Settings {
    
    static let shared = Settings()
    
    var scrollDuration = 400  //ms
    var useBounceEffect: Bool = true
    var accelerationMultiplier: Float = 3.0
    
    //    var bezierControlPoint1 = CGPoint.init(x: 0.34, y: 0.42)
    //    var bezierControlPoint2 = CGPoint.init(x: 0.25, y: 1)
    var bezierControlPoint1 = CGPoint.init(x: 0.3, y: 0.4)
    var bezierControlPoint2 = CGPoint.init(x: 0.37, y: 1)
    //    var bezierControlPoint1 = CGPoint.init(x: 0.44, y: 0.32)
    //    var bezierControlPoint2 = CGPoint.init(x: 0.41, y: 0.95)
    
    private init() {

    }
    
}
