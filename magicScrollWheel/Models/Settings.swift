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
    
    var scrollDuration = 500 //ms
    var useSystemDamping: Bool = false
    var emitateTrackpadTale: Bool = true
    
    private init() {
//        useSystemDamping = false
//        emitateTrackpadTale = false
    }
    
}
