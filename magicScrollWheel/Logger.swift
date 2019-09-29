//
//  Logger.swift
//  magicScrollWheel
//
//  Created by Aleksandr Kozhevnikov on 29/09/2019.
//  Copyright © 2019 Aleksandr Kozhevnikov. All rights reserved.
//

import Foundation

func print(object: Any) {
    Logger.log(object)
}

/// Disable print() in production mode
class Logger {
    
    static let enabled = { () -> Bool in
        #if DEBUG
            return true
        #else
            return false
        #endif
    }()
    
    public static func log(_ items: Any...) {
        if self.enabled {
            let stringItem = items.map{"\($0)"}.joined(separator: ", ")
            Swift.print("\(stringItem)", terminator: "\n")
        }
    }
}
