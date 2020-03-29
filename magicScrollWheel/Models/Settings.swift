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
    
    var scrollDuration = 650  //ms
    var useBounceEffect: Bool = true
    var accelerationMultiplier = 1.0
    
    private init() {

    }
    
}
